package com.phoneproof.phoneproof

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.MediaDrm
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES20
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.StatFs
import android.os.SystemClock
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Size
import android.util.SizeF
import android.view.Display
import android.view.WindowManager
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.cert.X509Certificate
import java.security.spec.ECGenParameterSpec
import java.util.UUID
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
                // Tier A — read-only, no special permission. Quick reads.
                "drmInfo" -> result.success(drmInfo())
                "displayHdr" -> result.success(displayHdr())
                "systemFeatures" -> result.success(systemFeatures())
                "uptime" -> result.success(uptime())
                // Slow / blocking -> background thread to avoid ANR.
                "keyAttestation" -> runAsync(result) { keyAttestation() }
                "gpuInfo" -> runAsync(result) { gpuInfo() }
                "cameraSpecs" -> runAsync(result) { cameraSpecs() }
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
        if (Build.VERSION.SDK_INT < 29) return mapOf("status" to null, "available" to false)
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val out = HashMap<String, Any?>()
        out["status"] = pm.currentThermalStatus
        out["available"] = true
        // Thermal headroom (API 30+): fraction toward SEVERE throttling. 1.0 = at
        // the threshold; can exceed 1.0. NaN if unsupported or polled too fast.
        if (Build.VERSION.SDK_INT >= 30) {
            val hr = try { pm.getThermalHeadroom(0) } catch (_: Throwable) { Float.NaN }
            out["headroom"] = if (hr.isNaN() || hr.isInfinite()) null else hr.toDouble()
        }
        return out
    }

    // ---------------------------------------------------------------- Cameras

    /** Read CameraCharacteristics (no CAMERA permission needed) — real sensor. */
    private fun cameraSpecs(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        try {
            val cm = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            for (id in cm.cameraIdList) {
                try {
                    val c = cm.getCameraCharacteristics(id)
                    val facing = when (c.get(CameraCharacteristics.LENS_FACING)) {
                        0 -> "Front"; 1 -> "Back"; 2 -> "External"; else -> "Unknown"
                    }
                    // Default pixel array is the BINNED size on Quad-Bayer sensors
                    // (e.g. a 50MP sensor reports ~12.5MP). The true full resolution
                    // lives in the MAXIMUM_RESOLUTION key (API 31+) — prefer the larger.
                    var pixels: Long? = null
                    val pixel: Size? = c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
                    if (pixel != null) pixels = pixel.width.toLong() * pixel.height.toLong()
                    if (Build.VERSION.SDK_INT >= 31) {
                        val maxPixel: Size? =
                            c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE_MAXIMUM_RESOLUTION)
                        if (maxPixel != null) {
                            val maxTotal = maxPixel.width.toLong() * maxPixel.height.toLong()
                            if (pixels == null || maxTotal > pixels) pixels = maxTotal
                        }
                    }
                    val mp = if (pixels != null) pixels / 1_000_000.0 else null
                    val binnedMp = if (pixel != null)
                        (pixel.width.toLong() * pixel.height.toLong()) / 1_000_000.0 else null
                    val physical: SizeF? = c.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
                    val focal = c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                        ?.map { it.toDouble() } ?: emptyList()
                    val apertures = c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
                        ?.map { it.toDouble() } ?: emptyList()
                    val flash = c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                    val oisModes = c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)
                    val hasOis = oisModes != null && oisModes.any { it != 0 } // 0 = OFF
                    val physicalCount = if (Build.VERSION.SDK_INT >= 28)
                        (try { c.physicalCameraIds.size } catch (_: Throwable) { 0 }) else 0
                    out.add(
                        mapOf(
                            "id" to id,
                            "facing" to facing,
                            "megapixels" to mp,
                            "binnedMegapixels" to binnedMp,
                            "sensorWidthMm" to physical?.width?.toDouble(),
                            "sensorHeightMm" to physical?.height?.toDouble(),
                            "focalLengths" to focal,
                            "apertures" to apertures,
                            "hasFlash" to flash,
                            "hasOis" to hasOis,
                            "physicalCount" to physicalCount
                        )
                    )
                } catch (_: Throwable) { /* skip this camera */ }
            }
        } catch (_: Throwable) { /* camera service unavailable */ }
        return out
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

    // ---------------------------------------------------------------- DRM (Widevine)

    private fun drmInfo(): Map<String, Any?> {
        val widevine = UUID.fromString("edef8ba9-79d6-4ace-a3c8-27dcd51d21ed")
        if (!MediaDrm.isCryptoSchemeSupported(widevine)) {
            return mapOf("widevineSupported" to false)
        }
        var drm: MediaDrm? = null
        return try {
            drm = MediaDrm(widevine)
            val level = try { drm.getPropertyString("securityLevel") } catch (_: Throwable) { null }
            val version = try { drm.getPropertyString("version") } catch (_: Throwable) { null }
            val hdcp = try { drm.getPropertyString("hdcpLevel") } catch (_: Throwable) { null }
            val maxHdcp = try { drm.getPropertyString("maxHdcpLevel") } catch (_: Throwable) { null }
            mapOf(
                "widevineSupported" to true,
                "securityLevel" to (if (level.isNullOrBlank()) null else level),
                "version" to (if (version.isNullOrBlank()) null else version),
                "hdcpLevel" to (if (hdcp.isNullOrBlank()) null else hdcp),
                "maxHdcpLevel" to (if (maxHdcp.isNullOrBlank()) null else maxHdcp)
            )
        } catch (e: Throwable) {
            mapOf("widevineSupported" to true, "error" to (e.message ?: "unavailable"))
        } finally {
            try {
                if (drm != null) {
                    if (Build.VERSION.SDK_INT >= 28) drm.close() else @Suppress("DEPRECATION") drm.release()
                }
            } catch (_: Throwable) { }
        }
    }

    // ---------------------------------------------------------------- Display HDR / gamut

    @Suppress("DEPRECATION")
    private fun displayHdr(): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val display = wm.defaultDisplay
            if (Build.VERSION.SDK_INT >= 26) {
                out["wideColorGamut"] = display.isWideColorGamut
                val caps = display.hdrCapabilities
                val types = caps?.supportedHdrTypes ?: IntArray(0)
                out["hdrTypes"] = types.map {
                    when (it) {
                        Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION -> "Dolby Vision"
                        Display.HdrCapabilities.HDR_TYPE_HDR10 -> "HDR10"
                        Display.HdrCapabilities.HDR_TYPE_HLG -> "HLG"
                        4 /* HDR_TYPE_HDR10_PLUS */ -> "HDR10+"
                        else -> "Type $it"
                    }
                }
                out["maxLuminance"] = caps?.desiredMaxLuminance?.takeIf { it > 0 }
            } else {
                out["wideColorGamut"] = null
                out["hdrTypes"] = emptyList<String>()
            }
        } catch (e: Throwable) {
            out["error"] = e.message
        }
        return out
    }

    // ---------------------------------------------------------------- System features

    private fun systemFeatures(): Map<String, Any?> {
        val pm = context.packageManager
        fun has(name: String) = try { pm.hasSystemFeature(name) } catch (_: Throwable) { false }
        // Curated, recognisable hardware features. Reported exactly as the OS says.
        val map = linkedMapOf(
            "NFC" to has(PackageManager.FEATURE_NFC),
            "Fingerprint" to has(PackageManager.FEATURE_FINGERPRINT),
            "Face unlock" to has("android.hardware.biometrics.face"),
            "IR blaster" to has(PackageManager.FEATURE_CONSUMER_IR),
            "Telephony" to has(PackageManager.FEATURE_TELEPHONY),
            "Bluetooth LE" to has(PackageManager.FEATURE_BLUETOOTH_LE),
            "Wi-Fi" to has(PackageManager.FEATURE_WIFI),
            "Wi-Fi Aware" to has(PackageManager.FEATURE_WIFI_AWARE),
            "USB host (OTG)" to has(PackageManager.FEATURE_USB_HOST),
            "GPS" to has(PackageManager.FEATURE_LOCATION_GPS),
            "Camera flash" to has(PackageManager.FEATURE_CAMERA_FLASH),
            "Front camera" to has(PackageManager.FEATURE_CAMERA_FRONT),
            "Barometer" to has(PackageManager.FEATURE_SENSOR_BAROMETER),
            "Compass" to has(PackageManager.FEATURE_SENSOR_COMPASS),
            "StrongBox keystore" to (Build.VERSION.SDK_INT >= 28 && has(PackageManager.FEATURE_STRONGBOX_KEYSTORE))
        )
        return mapOf("features" to map)
    }

    // ---------------------------------------------------------------- Uptime / boot

    private fun uptime(): Map<String, Any?> {
        val elapsed = SystemClock.elapsedRealtime() // ms since boot, including deep sleep
        val bootEpochMs = System.currentTimeMillis() - elapsed
        return mapOf(
            "uptimeMs" to elapsed,
            "bootEpochMs" to bootEpochMs
        )
    }

    // ---------------------------------------------------------------- GPU (OpenGL ES)

    /** Spin up a 1x1 offscreen EGL context purely to read the real GPU strings. */
    private fun gpuInfo(): Map<String, Any?> {
        val eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) return mapOf("available" to false)
        val version = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) return mapOf("available" to false)
        try {
            val cfgAttribs = intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_NONE
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val num = IntArray(1)
            if (!EGL14.eglChooseConfig(eglDisplay, cfgAttribs, 0, configs, 0, 1, num, 0) || num[0] == 0) {
                return mapOf("available" to false)
            }
            val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
            val ctx = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)
            val surfAttribs = intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
            val surface = EGL14.eglCreatePbufferSurface(eglDisplay, configs[0], surfAttribs, 0)
            EGL14.eglMakeCurrent(eglDisplay, surface, surface, ctx)
            val renderer = GLES20.glGetString(GLES20.GL_RENDERER)
            val vendor = GLES20.glGetString(GLES20.GL_VENDOR)
            val glVersion = GLES20.glGetString(GLES20.GL_VERSION)
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(eglDisplay, surface)
            EGL14.eglDestroyContext(eglDisplay, ctx)
            return mapOf(
                "available" to true,
                "renderer" to renderer,
                "vendor" to vendor,
                "glVersion" to glVersion
            )
        } catch (e: Throwable) {
            return mapOf("available" to false, "error" to (e.message ?: "unavailable"))
        } finally {
            try { EGL14.eglTerminate(eglDisplay) } catch (_: Throwable) { }
        }
    }

    // ---------------------------------------------------------------- Key Attestation

    /**
     * Generate a throwaway hardware-backed key with an attestation challenge and
     * read the Google-signed attestation extension for the *real* verified-boot
     * state and bootloader lock status. Everything degrades to "unsupported"
     * with a reason — we never fabricate a verdict.
     */
    private fun keyAttestation(): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < 24) return mapOf("supported" to false, "reason" to "Needs Android 7+")
        val alias = "phoneproof_attest_probe"
        var ks: KeyStore? = null
        return try {
            ks = KeyStore.getInstance("AndroidKeyStore")
            ks.load(null)
            try { ks.deleteEntry(alias) } catch (_: Throwable) { }
            val challenge = ByteArray(16).also { Random.Default.nextBytes(it) }
            val spec = KeyGenParameterSpec.Builder(
                alias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setAttestationChallenge(challenge)
                .build()
            val kpg = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
            kpg.initialize(spec)
            kpg.generateKeyPair()

            val chain = ks.getCertificateChain(alias)
            if (chain == null || chain.isEmpty()) {
                return mapOf("supported" to false, "reason" to "No attestation certificate chain")
            }
            val leaf = chain[0] as X509Certificate
            // Chain rooted in a Google attestation root is the trust anchor; we
            // report chain length so the UI can note hardware-backed provenance.
            val rooted = chain.size >= 2
            val ext = leaf.getExtensionValue("1.3.6.1.4.1.11129.2.1.17")
            val out = HashMap<String, Any?>()
            out["supported"] = true
            out["hardwareBacked"] = rooted
            out["chainLength"] = chain.size
            if (ext == null) {
                out["reason"] = "No attestation extension in certificate"
            } else {
                try {
                    parseAttestation(ext, out)
                } catch (e: Throwable) {
                    out["parseError"] = e.message ?: "parse failed"
                }
            }
            out
        } catch (e: Throwable) {
            mapOf("supported" to false, "reason" to (e.message ?: "Attestation unavailable"))
        } finally {
            try { ks?.deleteEntry(alias) } catch (_: Throwable) { }
        }
    }

    // ---- Minimal DER walker, just enough to reach RootOfTrust ----

    private class Der(val firstByte: Int, val tagNo: Long, val contentStart: Int, val contentLen: Int) {
        val end get() = contentStart + contentLen
        val isContext get() = (firstByte and 0xC0) == 0x80
    }

    private fun readDer(b: ByteArray, pos: Int): Der {
        var i = pos
        val first = b[i].toInt() and 0xFF; i++
        var tagNo: Long = (first and 0x1F).toLong()
        if ((first and 0x1F) == 0x1F) {
            tagNo = 0
            while (true) {
                val o = b[i].toInt() and 0xFF; i++
                tagNo = (tagNo shl 7) or (o and 0x7F).toLong()
                if (o and 0x80 == 0) break
            }
        }
        var len = b[i].toInt() and 0xFF; i++
        if (len and 0x80 != 0) {
            val n = len and 0x7F
            len = 0
            for (k in 0 until n) { len = (len shl 8) or (b[i].toInt() and 0xFF); i++ }
        }
        return Der(first, tagNo, i, len)
    }

    private fun derLong(b: ByteArray, t: Der): Long {
        var v = 0L
        for (k in t.contentStart until t.end) v = (v shl 8) or (b[k].toInt() and 0xFF).toLong()
        return v
    }

    /** Walk KeyDescription -> teeEnforced -> RootOfTrust and fill verified-boot fields. */
    private fun parseAttestation(extValue: ByteArray, out: HashMap<String, Any?>) {
        // extValue is a DER OCTET STRING wrapping the KeyDescription SEQUENCE.
        val octet = readDer(extValue, 0)
        val seqStart = octet.contentStart
        val keyDesc = readDer(extValue, seqStart) // SEQUENCE (KeyDescription)

        // Iterate KeyDescription children in order.
        val children = ArrayList<Der>()
        var p = keyDesc.contentStart
        while (p < keyDesc.end) {
            val d = readDer(extValue, p)
            children.add(d)
            p = d.end
        }
        // [1] attestationSecurityLevel ENUM
        if (children.size > 1) {
            out["securityLevel"] = secLevelName(derLong(extValue, children[1]).toInt())
        }
        // [6] softwareEnforced, [7] teeEnforced
        val authLists = listOfNotNull(children.getOrNull(7), children.getOrNull(6))
        for (auth in authLists) {
            var ap = auth.contentStart
            while (ap < auth.end) {
                val tagged = readDer(extValue, ap)
                if (tagged.isContext && tagged.tagNo == 704L) {
                    // EXPLICIT RootOfTrust SEQUENCE
                    val rot = readDer(extValue, tagged.contentStart)
                    var rp = rot.contentStart
                    val rotChildren = ArrayList<Der>()
                    while (rp < rot.end) { val d = readDer(extValue, rp); rotChildren.add(d); rp = d.end }
                    // 0: verifiedBootKey OCTET, 1: deviceLocked BOOLEAN, 2: verifiedBootState ENUM
                    rotChildren.getOrNull(1)?.let {
                        out["deviceLocked"] = (extValue[it.contentStart].toInt() and 0xFF) != 0
                    }
                    rotChildren.getOrNull(2)?.let {
                        out["verifiedBootState"] = bootStateName(derLong(extValue, it).toInt())
                    }
                } else if (tagged.isContext && tagged.tagNo == 706L) {
                    // EXPLICIT osPatchLevel INTEGER (YYYYMM)
                    val inner = readDer(extValue, tagged.contentStart)
                    out["osPatchLevel"] = derLong(extValue, inner)
                }
                ap = tagged.end
            }
            if (out.containsKey("verifiedBootState")) break
        }
    }

    private fun secLevelName(v: Int) = when (v) {
        0 -> "Software"
        1 -> "Trusted Environment (TEE)"
        2 -> "StrongBox"
        else -> "Level $v"
    }

    private fun bootStateName(v: Int) = when (v) {
        0 -> "Verified"
        1 -> "Self-signed"
        2 -> "Unverified"
        3 -> "Failed"
        else -> "State $v"
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
