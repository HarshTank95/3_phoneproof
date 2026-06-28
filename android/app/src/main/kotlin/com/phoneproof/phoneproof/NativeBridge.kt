package com.phoneproof.phoneproof

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.StatFs
import android.view.WindowManager
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.min
import kotlin.random.Random

/**
 * Native data layer for PhoneProof. Everything here is best-effort and degrades
 * gracefully: a value that the device does not expose is returned as null or -1,
 * never fabricated. Heavy work (storage / cpu benchmarks) runs off the main
 * thread and replies on the main thread.
 */
class NativeBridge(private val context: Context) {

    private val main = Handler(Looper.getMainLooper())

    fun handle(method: String, args: Any?, result: MethodChannel.Result) {
        // Quick reads run on the platform main thread. This matters for
        // batteryProperties: the sticky ACTION_BATTERY_CHANGED is only returned
        // for a null receiver when registered from the main thread (off-thread
        // it logs "no app for null" and returns null -> everything blank).
        // Only the genuinely slow calls go to a background thread.
        try {
            when (method) {
                "batteryProperties" -> result.success(batteryProperties())
                "thermalStatus" -> result.success(thermalStatus())
                "displayMetrics" -> result.success(displayMetrics())
                "sensorList" -> result.success(sensorList())
                "memInfo" -> result.success(memInfo())
                "cpuInfo" -> result.success(cpuInfo())
                "storageInfo" -> result.success(storageInfo())
                "buildInfo" -> result.success(buildInfo())
                "shizukuAvailable" -> result.success(shizukuAvailable())
                // Slow / blocking -> background thread to avoid ANR.
                "emulatorRoot" -> runAsync(result) { emulatorRoot() }
                "storageWriteVerify" -> runAsync(result) {
                    val sizeMb = (args as? Map<*, *>)?.get("sampleMb") as? Int ?: 64
                    storageWriteVerify(sizeMb)
                }
                "storageSpeed" -> runAsync(result) { storageSpeed() }
                "cpuBenchmark" -> runAsync(result) { cpuBenchmark() }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("native_error", e.message, null)
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        Thread {
            val reply: Any? = try {
                block()
            } catch (e: Throwable) {
                mapOf("error" to (e.message ?: "unknown"))
            }
            main.post { result.success(reply) }
        }.start()
    }

    // ---------------------------------------------------------------- Battery

    private fun batteryProperties(): Map<String, Any?> {
        val out = HashMap<String, Any?>()

        // Each property is read independently: on some OEM builds (e.g. Nothing
        // Phone / Android 15) getIntProperty for CYCLE_COUNT / STATE_OF_HEALTH
        // throws SecurityException (BATTERY_STATS) instead of returning a value,
        // and that must not wipe the rest of the battery card.
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        out["chargeCounter"] = safeIntProp(bm, BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        out["currentNow"] = safeIntProp(bm, BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        out["currentAverage"] = safeIntProp(bm, BatteryManager.BATTERY_PROPERTY_CURRENT_AVERAGE)
        out["capacityPercent"] = safeIntProp(bm, BatteryManager.BATTERY_PROPERTY_CAPACITY)
        out["energyCounter"] = safeLongProp(bm, BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)
        if (Build.VERSION.SDK_INT >= 34) {
            out["cycleCount"] = safeIntProp(bm, /* CHARGING_CYCLE_COUNT */ 9)
        }
        if (Build.VERSION.SDK_INT >= 35) {
            out["stateOfHealth"] = safeIntProp(bm, /* STATE_OF_HEALTH */ 10)
            out["manufacturingDateEpoch"] = safeLongProp(bm, /* MANUFACTURING_DATE */ 11)
            out["firstUsageDateEpoch"] = safeLongProp(bm, /* FIRST_USAGE_DATE */ 12)
        }

        // sysfs real mAh — readable on some devices without root; -1 otherwise.
        out["chargeFull"] = readSysfsLong("/sys/class/power_supply/battery/charge_full")
        out["chargeFullDesign"] = readSysfsLong("/sys/class/power_supply/battery/charge_full_design")

        // Sticky broadcast: legacy health, temp, voltage, tech, plug state (all versions).
        // Use a REAL (empty) receiver, not null: a null receiver returns no sticky
        // intent on several OEM builds ("no app for null"). Registering a throwaway
        // receiver reliably returns the current sticky ACTION_BATTERY_CHANGED, then
        // we immediately unregister it. Guarded so a failure never blanks the rest.
        val intent: Intent? = try {
            val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, i: Intent?) {}
            }
            val sticky = if (Build.VERSION.SDK_INT >= 33) {
                context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                context.registerReceiver(receiver, filter)
            }
            try {
                context.unregisterReceiver(receiver)
            } catch (_: Throwable) { }
            sticky
        } catch (e: Throwable) {
            null
        }
        if (intent != null) {
            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            out["levelPercent"] = if (level >= 0 && scale > 0) (level * 100 / scale) else null
            out["temperatureTenthC"] = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
            out["voltageMilliV"] = intent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, Int.MIN_VALUE)
            out["technology"] = intent.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)
            out["healthRaw"] = intent.getIntExtra(BatteryManager.EXTRA_HEALTH, 0)
            out["statusRaw"] = intent.getIntExtra(BatteryManager.EXTRA_STATUS, 0)
            out["pluggedRaw"] = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
            out["present"] = intent.getBooleanExtra(BatteryManager.EXTRA_PRESENT, false)
        }
        return out
    }

    // Each read is independently guarded: some properties throw SecurityException
    // (BATTERY_STATS) on certain OEM builds rather than returning a sentinel.
    private fun safeIntProp(bm: BatteryManager, id: Int): Int? {
        return try {
            val v = bm.getIntProperty(id)
            if (v == Int.MIN_VALUE || v == Int.MAX_VALUE) null else v
        } catch (e: Throwable) {
            null
        }
    }

    private fun safeLongProp(bm: BatteryManager, id: Int): Long? {
        return try {
            val v = bm.getLongProperty(id)
            if (v == Long.MIN_VALUE || v == Long.MAX_VALUE) null else v
        } catch (e: Throwable) {
            null
        }
    }

    // ---------------------------------------------------------------- Thermal

    private fun thermalStatus(): Map<String, Any?> {
        return if (Build.VERSION.SDK_INT >= 29) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val status = pm.currentThermalStatus
            mapOf("status" to status, "available" to true)
        } else {
            mapOf("status" to null, "available" to false)
        }
    }

    // ---------------------------------------------------------------- Display

    @Suppress("DEPRECATION")
    private fun displayMetrics(): Map<String, Any?> {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val display = wm.defaultDisplay
        val dm = android.util.DisplayMetrics()
        display.getRealMetrics(dm)
        val rates = display.supportedModes.map {
            mapOf(
                "width" to it.physicalWidth,
                "height" to it.physicalHeight,
                "refreshRate" to it.refreshRate
            )
        }
        return mapOf(
            "widthPx" to dm.widthPixels,
            "heightPx" to dm.heightPixels,
            "densityDpi" to dm.densityDpi,
            "density" to dm.density,
            "xdpi" to dm.xdpi,
            "ydpi" to dm.ydpi,
            "refreshRate" to display.refreshRate,
            "supportedModes" to rates
        )
    }

    // ---------------------------------------------------------------- Sensors

    private fun sensorList(): List<Map<String, Any?>> {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        return sm.getSensorList(Sensor.TYPE_ALL).map {
            mapOf(
                "name" to it.name,
                "type" to it.type,
                "vendor" to it.vendor,
                "version" to it.version,
                "power" to it.power,
                "resolution" to it.resolution,
                "maximumRange" to it.maximumRange
            )
        }
    }

    // ---------------------------------------------------------------- Memory

    private fun memInfo(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        try {
            File("/proc/meminfo").forEachLine { line ->
                val parts = line.split(":")
                if (parts.size == 2) {
                    val key = parts[0].trim()
                    val kb = parts[1].trim().removeSuffix(" kB").trim().toLongOrNull()
                    if (kb != null) {
                        when (key) {
                            "MemTotal" -> out["memTotalKb"] = kb
                            "MemAvailable" -> out["memAvailableKb"] = kb
                            "SwapTotal" -> out["swapTotalKb"] = kb
                            "SwapFree" -> out["swapFreeKb"] = kb
                        }
                    }
                }
            }
        } catch (_: Throwable) { /* ignore */ }

        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)
        out["amTotalMem"] = mi.totalMem
        out["amAvailMem"] = mi.availMem
        out["amLowMemory"] = mi.lowMemory
        out["amThreshold"] = mi.threshold

        // zRAM presence => "virtual RAM" feature.
        out["zramTotalBytes"] = readSysfsLong("/sys/block/zram0/disksize")
        out["hasSwap"] = (out["swapTotalKb"] as? Long ?: 0L) > 0L
        return out
    }

    // ---------------------------------------------------------------- CPU

    private fun cpuInfo(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        val cores = Runtime.getRuntime().availableProcessors()
        out["cores"] = cores
        out["abis"] = Build.SUPPORTED_ABIS.toList()

        var hardware: String? = null
        try {
            File("/proc/cpuinfo").forEachLine { line ->
                val l = line.lowercase()
                if (hardware == null && (l.startsWith("hardware") || l.startsWith("model name") || l.startsWith("processor\t: arm"))) {
                    val idx = line.indexOf(":")
                    if (idx >= 0) hardware = line.substring(idx + 1).trim()
                }
            }
        } catch (_: Throwable) { }
        out["hardware"] = hardware

        val freqs = ArrayList<Long>()
        for (i in 0 until cores) {
            val f = readSysfsLong("/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq")
            freqs.add(f) // kHz, or -1
        }
        out["perCoreMaxFreqKhz"] = freqs
        out["maxFreqKhz"] = freqs.filter { it > 0 }.maxOrNull() ?: -1L
        return out
    }

    // ---------------------------------------------------------------- Storage

    private fun storageInfo(): Map<String, Any?> {
        val dataDir = context.filesDir
        val stat = StatFs(dataDir.absolutePath)
        val total = stat.blockCountLong * stat.blockSizeLong
        val free = stat.availableBlocksLong * stat.blockSizeLong

        // External / primary storage if available.
        var extTotal = -1L
        var extFree = -1L
        try {
            val ext = context.getExternalFilesDir(null)
            if (ext != null) {
                val es = StatFs(ext.absolutePath)
                extTotal = es.blockCountLong * es.blockSizeLong
                extFree = es.availableBlocksLong * es.blockSizeLong
            }
        } catch (_: Throwable) { }

        return mapOf(
            "dataTotalBytes" to total,
            "dataFreeBytes" to free,
            "externalTotalBytes" to extTotal,
            "externalFreeBytes" to extFree
        )
    }

    /**
     * Write pseudo-random data and read it back to confirm real usable capacity.
     * Spot-checks a bounded sample (never fills the disk). Returns verified flag
     * and any mismatch byte count.
     */
    private fun storageWriteVerify(sampleMbRequested: Int): Map<String, Any?> {
        val dir = context.cacheDir
        val stat = StatFs(dir.absolutePath)
        val freeBytes = stat.availableBlocksLong * stat.blockSizeLong
        // Cap sample so we never use more than 1/4 of free space, and never > 256MB.
        val maxSafe = min(freeBytes / 4, 256L * 1024 * 1024)
        val sampleBytes = min(sampleMbRequested.toLong() * 1024 * 1024, maxSafe).coerceAtLeast(1L * 1024 * 1024)

        val file = File(dir, "phoneproof_verify.bin")
        val chunk = 1 * 1024 * 1024 // 1 MB
        val seed = System.nanoTime()
        var mismatch = 0L
        var written = 0L
        try {
            // Write
            RandomAccessFile(file, "rw").use { raf ->
                val rnd = Random(seed)
                val buf = ByteArray(chunk)
                while (written < sampleBytes) {
                    rnd.nextBytes(buf)
                    val toWrite = min(chunk.toLong(), sampleBytes - written).toInt()
                    raf.write(buf, 0, toWrite)
                    written += toWrite
                }
                raf.fd.sync()
            }
            // Read back & verify against the same seeded stream.
            RandomAccessFile(file, "r").use { raf ->
                val rnd = Random(seed)
                val expected = ByteArray(chunk)
                val actual = ByteArray(chunk)
                var read = 0L
                while (read < written) {
                    rnd.nextBytes(expected)
                    val toRead = min(chunk.toLong(), written - read).toInt()
                    var off = 0
                    while (off < toRead) {
                        val r = raf.read(actual, off, toRead - off)
                        if (r < 0) break
                        off += r
                    }
                    for (i in 0 until toRead) {
                        if (actual[i] != expected[i]) mismatch++
                    }
                    read += toRead
                }
            }
        } finally {
            file.delete()
        }
        return mapOf(
            "sampleBytes" to written,
            "mismatchBytes" to mismatch,
            "verified" to (mismatch == 0L && written > 0L),
            "freeBytes" to freeBytes
        )
    }

    private fun storageSpeed(): Map<String, Any?> {
        val dir = context.cacheDir
        val file = File(dir, "phoneproof_speed.bin")
        val totalBytes = 32L * 1024 * 1024 // 32 MB benchmark
        val chunk = 1 * 1024 * 1024
        val buf = ByteArray(chunk)
        Random(1).nextBytes(buf)
        var seqWriteMbps = -1.0
        var seqReadMbps = -1.0
        var randReadMbps = -1.0
        try {
            // Sequential write
            var t0 = System.nanoTime()
            RandomAccessFile(file, "rw").use { raf ->
                var w = 0L
                while (w < totalBytes) {
                    raf.write(buf)
                    w += chunk
                }
                raf.fd.sync()
            }
            var dt = (System.nanoTime() - t0) / 1e9
            seqWriteMbps = (totalBytes / (1024.0 * 1024.0)) / dt

            // Sequential read
            t0 = System.nanoTime()
            RandomAccessFile(file, "r").use { raf ->
                var r = 0L
                while (r < totalBytes) {
                    val got = raf.read(buf)
                    if (got < 0) break
                    r += got
                }
            }
            dt = (System.nanoTime() - t0) / 1e9
            seqReadMbps = (totalBytes / (1024.0 * 1024.0)) / dt

            // Random 4K reads
            val blocks = (totalBytes / chunk).toInt()
            val small = ByteArray(4096)
            val rnd = Random(7)
            val ops = 2000
            t0 = System.nanoTime()
            RandomAccessFile(file, "r").use { raf ->
                repeat(ops) {
                    val pos = (rnd.nextInt(blocks) * chunk).toLong() +
                        rnd.nextInt(chunk / 4096) * 4096L
                    raf.seek(pos)
                    raf.read(small)
                }
            }
            dt = (System.nanoTime() - t0) / 1e9
            randReadMbps = (ops * 4096.0 / (1024.0 * 1024.0)) / dt
        } finally {
            file.delete()
        }
        return mapOf(
            "seqWriteMbps" to seqWriteMbps,
            "seqReadMbps" to seqReadMbps,
            "randReadMbps" to randReadMbps
        )
    }

    // ---------------------------------------------------------------- CPU bench

    private fun cpuBenchmark(): Map<String, Any?> {
        // Single-thread integer/float workload; higher score = faster.
        val start = System.nanoTime()
        var acc = 0.0
        var x = 1.0000001
        for (i in 0 until 30_000_000) {
            acc += x
            x *= 1.0000000007
            if (x > 2.0) x = 1.0000001
        }
        val singleMs = (System.nanoTime() - start) / 1e6

        // Multi-thread: spread the same work across all cores.
        val cores = Runtime.getRuntime().availableProcessors()
        val mtStart = System.nanoTime()
        val threads = (0 until cores).map {
            Thread {
                var a = 0.0
                var y = 1.0000001
                for (i in 0 until 30_000_000) {
                    a += y
                    y *= 1.0000000007
                    if (y > 2.0) y = 1.0000001
                }
            }
        }
        threads.forEach { it.start() }
        threads.forEach { it.join() }
        val multiMs = (System.nanoTime() - mtStart) / 1e6

        // Normalised scores (arbitrary but stable): reference ~ 300ms single.
        val singleScore = (60000.0 / singleMs).toInt().coerceAtLeast(1)
        val multiScore = (60000.0 / multiMs * cores).toInt().coerceAtLeast(1)
        // keep accumulator alive so JIT can't elide the loop
        return mapOf(
            "singleMs" to singleMs,
            "multiMs" to multiMs,
            "singleScore" to singleScore,
            "multiScore" to multiScore,
            "cores" to cores,
            "checksum" to (acc.toLong() % 100000)
        )
    }

    // ---------------------------------------------------------------- Build

    private fun buildInfo(): Map<String, Any?> {
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "hardware" to Build.HARDWARE,
            "board" to Build.BOARD,
            "fingerprint" to Build.FINGERPRINT,
            "tags" to Build.TAGS,
            "type" to Build.TYPE,
            "host" to Build.HOST,
            "bootloader" to Build.BOOTLOADER,
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "securityPatch" to (if (Build.VERSION.SDK_INT >= 23) Build.VERSION.SECURITY_PATCH else null)
        )
    }

    // ---------------------------------------------------------------- Heuristics

    private fun emulatorRoot(): Map<String, Any?> {
        val emuReasons = ArrayList<String>()
        val fp = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val product = Build.PRODUCT.lowercase()
        val brand = Build.BRAND.lowercase()
        val device = Build.DEVICE.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()

        if (fp.startsWith("generic") || fp.contains("vbox") || fp.contains("test-keys") && fp.contains("generic"))
            emuReasons.add("Generic build fingerprint")
        if (model.contains("google_sdk") || model.contains("emulator") || model.contains("android sdk built for"))
            emuReasons.add("Emulator model name")
        if (product.contains("sdk") || product.contains("emulator") || product.contains("vbox") || product == "google_sdk")
            emuReasons.add("Emulator product name")
        if (brand.startsWith("generic") && device.startsWith("generic"))
            emuReasons.add("Generic brand/device")
        if (hardware.contains("goldfish") || hardware.contains("ranchu") || hardware.contains("vbox") || hardware.contains("ttvm"))
            emuReasons.add("Emulator hardware")
        if (manufacturer.contains("genymotion") || product.contains("genymotion"))
            emuReasons.add("Genymotion")
        if (Build.HOST.lowercase().contains("build")) { /* common, ignore */ }
        // QEMU pipe files
        for (p in listOf("/dev/socket/qemud", "/dev/qemu_pipe", "/system/lib/libc_malloc_debug_qemu.so")) {
            if (File(p).exists()) { emuReasons.add("QEMU artifact present"); break }
        }

        val rootReasons = ArrayList<String>()
        if (Build.TAGS != null && Build.TAGS.contains("test-keys"))
            rootReasons.add("Build signed with test-keys")
        val suPaths = listOf(
            "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su", "/system/xbin/su",
            "/data/local/xbin/su", "/data/local/bin/su", "/system/sd/xbin/su",
            "/system/bin/failsafe/su", "/data/local/su", "/su/bin/su",
            "/system/xbin/daemonsu", "/system/bin/magisk"
        )
        for (p in suPaths) {
            if (File(p).exists()) { rootReasons.add("su/magisk binary found"); break }
        }
        for (p in listOf("/sbin/.magisk", "/data/adb/magisk", "/data/adb/modules")) {
            if (File(p).exists()) { rootReasons.add("Magisk directory found"); break }
        }
        // Which su on PATH
        try {
            val proc = ProcessBuilder("which", "su").redirectErrorStream(true).start()
            val out = proc.inputStream.bufferedReader().readText().trim()
            proc.waitFor()
            if (out.isNotEmpty() && out.contains("su")) rootReasons.add("su resolvable on PATH")
        } catch (_: Throwable) { }

        return mapOf(
            "isEmulator" to emuReasons.isNotEmpty(),
            "emulatorReasons" to emuReasons,
            "isRooted" to rootReasons.isNotEmpty(),
            "rootReasons" to rootReasons,
            "bootloaderUnlockedHint" to (Build.TAGS?.contains("test-keys") == true)
        )
    }

    // ---------------------------------------------------------------- Shizuku

    private fun shizukuAvailable(): Map<String, Any?> {
        // We detect the Shizuku manager app's presence so the UI can offer the
        // privileged upgrade path. Full AIDL binding is out of scope; absence
        // simply means those values stay "Not reported".
        val installed = try {
            context.packageManager.getPackageInfo("moe.shizuku.privileged.api", 0)
            true
        } catch (_: Throwable) {
            false
        }
        return mapOf("installed" to installed, "bound" to false)
    }

    // ---------------------------------------------------------------- Helpers

    private fun readSysfsLong(path: String): Long {
        return try {
            val f = File(path)
            if (!f.canRead()) -1L
            else f.readText().trim().toLongOrNull() ?: -1L
        } catch (_: Throwable) {
            -1L
        }
    }
}
