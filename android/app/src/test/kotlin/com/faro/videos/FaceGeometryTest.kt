package com.faro.videos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FaceGeometryTest {
    private val eps = 1e-6

    private fun assertPlacement(expected: Placement, actual: Placement?) {
        requireNotNull(actual)
        assertEquals(expected.cx, actual.cx, eps)
        assertEquals(expected.cy, actual.cy, eps)
        assertEquals(expected.w, actual.w, eps)
        assertEquals(expected.thetaDeg, actual.thetaDeg, eps)
    }

    @Test
    fun tiltIsClockwisePositiveAndIndependentOfEyeOrder() {
        val tilted = FaceInput(leftEye = Point(100.0, 100.0), rightEye = Point(200.0, 200.0))
        assertEquals(45.0, FaceGeometry.tiltDegrees(tilted), eps)
        val swapped = FaceInput(leftEye = Point(200.0, 200.0), rightEye = Point(100.0, 100.0))
        assertEquals(45.0, FaceGeometry.tiltDegrees(swapped), eps)
        assertEquals(0.0, FaceGeometry.tiltDegrees(FaceInput()), eps)
    }

    @Test
    fun sunglassesCenteredBetweenEyesTwiceTheDistance() {
        val face = FaceInput(leftEye = Point(100.0, 200.0), rightEye = Point(160.0, 200.0))
        assertPlacement(Placement(130.0, 200.0, 120.0, 0.0), FaceGeometry.placement(face, FilterKind.SUNGLASSES))
        assertNull(FaceGeometry.placement(FaceInput(leftEye = Point(1.0, 1.0)), FilterKind.SUNGLASSES))
    }

    @Test
    fun mustacheUsesMouthWidthAndOffsetsBelowNose() {
        val face = FaceInput(
            leftEye = Point(100.0, 100.0),
            rightEye = Point(200.0, 100.0),
            noseBase = Point(150.0, 180.0),
            mouthLeft = Point(120.0, 220.0),
            mouthRight = Point(180.0, 220.0),
        )
        assertPlacement(Placement(150.0, 192.0, 78.0, 0.0), FaceGeometry.placement(face, FilterKind.MUSTACHE))
        val noMouth = face.copy(mouthLeft = null)
        assertPlacement(Placement(150.0, 192.0, 130.0, 0.0), FaceGeometry.placement(noMouth, FilterKind.MUSTACHE))
        assertNull(FaceGeometry.placement(face.copy(noseBase = null), FilterKind.MUSTACHE))
    }

    @Test
    fun mustacheOffsetRotatesWithTilt() {
        // Eyes at 90° clockwise: offset (0, 0.12·d) rotated by 90° points to −x.
        val face = FaceInput(leftEye = Point(0.0, 0.0), rightEye = Point(0.0, 100.0), noseBase = Point(50.0, 50.0))
        assertPlacement(Placement(38.0, 50.0, 130.0, 90.0), FaceGeometry.placement(face, FilterKind.MUSTACHE))
    }

    @Test
    fun crownSitsAboveTheBox() {
        val face = FaceInput(box = Box(100.0, 100.0, 200.0, 300.0))
        // w = 180, h = 180·360/600 = 108, anchor = (200, 115), center = (200, 115 − 54).
        assertPlacement(Placement(200.0, 61.0, 180.0, 0.0), FaceGeometry.placement(face, FilterKind.CROWN))
        assertNull(FaceGeometry.placement(FaceInput(), FilterKind.CROWN))
    }

    @Test
    fun trackInterpolatesAndHoldsExtremes() {
        val track = PlacementTrack(
            listOf(
                400L to Placement(0.6, 0.4, 0.3, 10.0),
                200L to Placement(0.2, 0.2, 0.1, -10.0),
            )
        )
        assertPlacement(Placement(0.2, 0.2, 0.1, -10.0), track.at(0))
        assertPlacement(Placement(0.4, 0.3, 0.2, 0.0), track.at(300))
        assertPlacement(Placement(0.5, 0.35, 0.25, 5.0), track.at(350))
        assertPlacement(Placement(0.6, 0.4, 0.3, 10.0), track.at(5000))
        assertNull(PlacementTrack(emptyList()).at(0))
    }

    @Test
    fun normalizeDividesByFrameSize() {
        assertPlacement(
            Placement(0.25, 0.5, 0.1, 7.0),
            PlacementTrack.normalize(Placement(100.0, 360.0, 40.0, 7.0), 400, 720),
        )
    }

    @Test
    fun overlayMappingUsesYUpNdcAndCounterClockwiseRotation() {
        val t = OverlayMapping.toOverlay(Placement(0.25, 0.25, 0.5, 30.0), frameWidth = 1280, spriteWidth = 1000)
        assertEquals(-0.5f, t.anchorX, 1e-6f)
        assertEquals(0.5f, t.anchorY, 1e-6f)
        assertEquals(0.64f, t.scale, 1e-6f)
        assertEquals(-30f, t.rotationDegrees, 1e-6f)
    }
}
