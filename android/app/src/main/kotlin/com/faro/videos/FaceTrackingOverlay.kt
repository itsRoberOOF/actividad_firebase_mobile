package com.faro.videos

import android.graphics.Bitmap
import android.util.Pair
import androidx.annotation.OptIn
import androidx.media3.common.OverlaySettings
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay

/** Draws [sprite] on every frame at the placement interpolated from [track] for that timestamp. */
@OptIn(UnstableApi::class)
class FaceTrackingOverlay(
    private val sprite: Bitmap,
    private val track: PlacementTrack,
) : BitmapOverlay() {
    private var frameWidth = 0

    override fun configure(videoSize: Size) {
        super.configure(videoSize)
        frameWidth = videoSize.width
    }

    override fun getBitmap(presentationTimeUs: Long): Bitmap = sprite

    override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
        val placement = track.at(presentationTimeUs / 1000) ?: return HIDDEN
        val t = OverlayMapping.toOverlay(placement, frameWidth, sprite.width)
        return FrameOverlaySettings(t)
    }

    // Implemented directly instead of StaticOverlaySettings because its builder rejects anchors
    // outside [-1, 1], and a crown can legitimately sit partly above the top edge.
    private class FrameOverlaySettings(private val t: OverlayTransform) : OverlaySettings {
        override fun getBackgroundFrameAnchor(): Pair<Float, Float> = Pair.create(t.anchorX, t.anchorY)
        override fun getScale(): Pair<Float, Float> = Pair.create(t.scale, t.scale)
        override fun getRotationDegrees(): Float = t.rotationDegrees
    }

    private companion object {
        val HIDDEN = object : OverlaySettings {
            override fun getAlphaScale(): Float = 0f
        }
    }
}
