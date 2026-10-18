package com.faro.videos

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

data class Point(val x: Double, val y: Double) {
    operator fun plus(o: Point) = Point(x + o.x, y + o.y)
    operator fun minus(o: Point) = Point(x - o.x, y - o.y)
    fun length() = hypot(x, y)
}

data class Box(val x: Double, val y: Double, val w: Double, val h: Double)

/** Face landmarks in analysis-image pixels (origin top-left, y down). Any of them may be missing. */
data class FaceInput(
    val leftEye: Point? = null,
    val rightEye: Point? = null,
    val noseBase: Point? = null,
    val mouthLeft: Point? = null,
    val mouthRight: Point? = null,
    val box: Box? = null,
)

enum class FilterKind(val wireName: String, val spriteWidth: Double, val spriteHeight: Double) {
    SUNGLASSES("sunglasses", 1000.0, 400.0),
    MUSTACHE("mustache", 600.0, 220.0),
    CROWN("crown", 600.0, 360.0);

    companion object {
        fun fromWireName(name: String?): FilterKind? = entries.firstOrNull { it.wireName == name }
    }
}

/** Sprite center (cx, cy), width w, and rotation [thetaDeg] (clockwise on screen, y down). */
data class Placement(val cx: Double, val cy: Double, val w: Double, val thetaDeg: Double)

object FaceGeometry {
    fun tiltDegrees(face: FaceInput): Double {
        val l = face.leftEye ?: return 0.0
        val r = face.rightEye ?: return 0.0
        var v = r - l
        if (v.x < 0) v = Point(-v.x, -v.y)
        return Math.toDegrees(atan2(v.y, v.x))
    }

    fun rotate(p: Point, thetaDeg: Double): Point {
        val t = Math.toRadians(thetaDeg)
        return Point(p.x * cos(t) - p.y * sin(t), p.x * sin(t) + p.y * cos(t))
    }

    fun placement(face: FaceInput, kind: FilterKind): Placement? {
        val theta = tiltDegrees(face)
        val aspect = kind.spriteHeight / kind.spriteWidth
        return when (kind) {
            FilterKind.SUNGLASSES -> {
                val l = face.leftEye ?: return null
                val r = face.rightEye ?: return null
                val d = (r - l).length()
                Placement((l.x + r.x) / 2, (l.y + r.y) / 2, 2.0 * d, theta)
            }
            FilterKind.MUSTACHE -> {
                val n = face.noseBase ?: return null
                val l = face.leftEye ?: return null
                val r = face.rightEye ?: return null
                val d = (r - l).length()
                val ml = face.mouthLeft
                val mr = face.mouthRight
                val mw = if (ml != null && mr != null) (mr - ml).length() else d
                val c = n + rotate(Point(0.0, 0.12 * d), theta)
                Placement(c.x, c.y, 1.3 * mw, theta)
            }
            FilterKind.CROWN -> {
                val b = face.box ?: return null
                val anchor = Point(b.x + b.w / 2, b.y + 0.05 * b.h)
                val w = 0.9 * b.w
                val h = w * aspect
                val c = anchor + rotate(Point(0.0, -h / 2), theta)
                Placement(c.x, c.y, w, theta)
            }
        }
    }
}

/**
 * Placements sampled over time, stored normalized to the analysis frame (cx/W, cy/H, w/W) so they
 * can be applied to an output frame of any resolution with the same aspect ratio.
 */
class PlacementTrack(samples: List<Pair<Long, Placement>>) {
    private val samples = samples.sortedBy { it.first }

    val isEmpty get() = samples.isEmpty()

    fun at(timeMs: Long): Placement? {
        if (samples.isEmpty()) return null
        val first = samples.first()
        val last = samples.last()
        if (timeMs <= first.first) return first.second
        if (timeMs >= last.first) return last.second
        val i = samples.indexOfFirst { it.first > timeMs }
        val (t0, p0) = samples[i - 1]
        val (t1, p1) = samples[i]
        val f = (timeMs - t0).toDouble() / (t1 - t0)
        fun lerp(a: Double, b: Double) = a + (b - a) * f
        return Placement(lerp(p0.cx, p1.cx), lerp(p0.cy, p1.cy), lerp(p0.w, p1.w), lerp(p0.thetaDeg, p1.thetaDeg))
    }

    companion object {
        fun normalize(p: Placement, frameWidth: Int, frameHeight: Int) =
            Placement(p.cx / frameWidth, p.cy / frameHeight, p.w / frameWidth, p.thetaDeg)
    }
}

/** Overlay parameters in Media3's OverlaySettings convention. */
data class OverlayTransform(val anchorX: Float, val anchorY: Float, val scale: Float, val rotationDegrees: Float)

object OverlayMapping {
    /**
     * Maps a normalized placement to Media3 OverlaySettings values for a frame [frameWidth] pixels
     * wide and a sprite bitmap [spriteWidth] pixels wide.
     *
     * Media3 conventions (OverlaySettings / OverlayMatrixProvider, 1.9.2):
     * - The background anchor is in NDC of the frame, x right and y UP, both in [-1, 1].
     * - With overlay anchor (0,0), scale (s, s) draws the overlay at s * its pixel size in frame
     *   pixels; the matrix already corrects for the non-square NDC, so a uniform scale keeps the
     *   sprite's aspect ratio and rotation does not shear.
     * - Rotation is counter-clockwise, so the contract's clockwise θ becomes −θ.
     */
    fun toOverlay(normalized: Placement, frameWidth: Int, spriteWidth: Int): OverlayTransform {
        val widthPx = normalized.w * frameWidth
        return OverlayTransform(
            anchorX = (2.0 * normalized.cx - 1.0).toFloat(),
            anchorY = (1.0 - 2.0 * normalized.cy).toFloat(),
            scale = (widthPx / spriteWidth).toFloat(),
            rotationDegrees = (-normalized.thetaDeg).toFloat(),
        )
    }
}
