#!/usr/bin/env swift

// Generates SleepRecord/Assets.xcassets/AppIcon.appiconset/icon-1024.png
// Spec: docs/superpowers/specs/2026-05-05-app-icon-design.md
//
// Run: swift tools/generate-icon.swift
// Deterministic: same script -> same PNG bytes.

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let canvas: CGFloat = 1024
let outputPath = "SleepRecord/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

// CG draws origin-bottom-left. Spec uses origin-top-left for readability.
// flipY converts spec-Y -> CG-Y.
func flipY(_ y: CGFloat) -> CGFloat { canvas - y }

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

// --- Sky palette: 3-stop gradient, brand-aligned with HomeView's night background ---
let skyTop      = CGColor(red: 0.040, green: 0.045, blue: 0.180, alpha: 1.0) // #0A0B2E
let skyMid      = CGColor(red: 0.105, green: 0.085, blue: 0.295, alpha: 1.0) // #1B164B
let skyBottom   = CGColor(red: 0.225, green: 0.165, blue: 0.430, alpha: 1.0) // #392A6E

// --- Moon palette: warm cream with a slightly cooler shadow side for dimension ---
let cream       = CGColor(red: 0.969, green: 0.949, blue: 0.871, alpha: 1.0) // #F7F2DE
let creamShadow = CGColor(red: 0.835, green: 0.808, blue: 0.706, alpha: 1.0) // #D5CEB4

// --- Atmospheric glow: warm haze in the sky + tighter halo around the moon ---
let warmHaze    = CGColor(red: 0.984, green: 0.910, blue: 0.690, alpha: 0.10) // #FBE8B0 @10%
let moonGlow    = CGColor(red: 0.984, green: 0.945, blue: 0.792, alpha: 0.32) // #FBF1CA @32%
let moonShadow  = CGColor(red: 0.984, green: 0.945, blue: 0.792, alpha: 0.55)

func white(_ a: CGFloat) -> CGColor { CGColor(red: 1, green: 1, blue: 1, alpha: a) }
func clear(_ c: CGColor) -> CGColor { c.copy(alpha: 0)! }

guard let ctx = CGContext(
    data: nil,
    width: Int(canvas),
    height: Int(canvas),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: sRGB,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("error: failed to create CGContext\n".utf8))
    exit(1)
}

let moonCenter = CGPoint(x: 512, y: flipY(495))
let moonR: CGFloat = 275

// --- 1) Sky: 3-stop vertical gradient ---
let skyGradient = CGGradient(
    colorsSpace: sRGB,
    colors: [skyTop, skyMid, skyBottom] as CFArray,
    locations: [0.0, 0.55, 1.0]
)!
ctx.drawLinearGradient(
    skyGradient,
    start: CGPoint(x: 0, y: canvas), // visual top
    end:   CGPoint(x: 0, y: 0),      // visual bottom
    options: []
)

// --- 1b) Atmospheric warm haze around where the moon will sit ---
let hazeGradient = CGGradient(
    colorsSpace: sRGB,
    colors: [warmHaze, clear(warmHaze)] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawRadialGradient(
    hazeGradient,
    startCenter: moonCenter, startRadius: 0,
    endCenter: moonCenter, endRadius: 480,
    options: []
)

// --- 2) Stars (drawn before the moon glow so the glow sits on top) ---
struct Star { let x, y, d, a: CGFloat; let twinkle: Bool }
let stars: [Star] = [
    // Upper-left field
    Star(x: 165, y: 175, d:  6, a: 0.55, twinkle: false),
    Star(x: 240, y: 235, d: 10, a: 0.72, twinkle: false),
    Star(x: 320, y: 130, d: 18, a: 0.92, twinkle: true),  // hero twinkle
    Star(x: 130, y: 350, d:  8, a: 0.50, twinkle: false),
    Star(x: 410, y: 200, d:  5, a: 0.45, twinkle: false),
    Star(x:  95, y: 510, d:  7, a: 0.45, twinkle: false),
    Star(x: 215, y: 410, d:  4, a: 0.40, twinkle: false),

    // Lower-right field
    Star(x: 760, y: 770, d:  7, a: 0.55, twinkle: false),
    Star(x: 870, y: 705, d:  5, a: 0.40, twinkle: false),
    Star(x: 720, y: 880, d: 15, a: 0.85, twinkle: true),  // hero twinkle
    Star(x: 850, y: 855, d:  8, a: 0.55, twinkle: false),
    Star(x: 940, y: 790, d:  5, a: 0.42, twinkle: false),
    Star(x: 670, y: 950, d:  4, a: 0.35, twinkle: false),
    Star(x: 815, y: 925, d:  6, a: 0.45, twinkle: false),
]

func drawStar(_ s: Star) {
    let cgY = flipY(s.y)
    let r = s.d / 2

    if s.twinkle {
        // Soft circular halo via radial gradient
        let haloR = s.d * 1.8
        let haloGradient = CGGradient(
            colorsSpace: sRGB,
            colors: [white(s.a * 0.40), white(0)] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawRadialGradient(
            haloGradient,
            startCenter: CGPoint(x: s.x, y: cgY), startRadius: 0,
            endCenter: CGPoint(x: s.x, y: cgY), endRadius: haloR,
            options: []
        )
        // Cross-shaped diffraction rays
        let rayLen = s.d * 2.6
        let rayWidth = max(s.d * 0.18, 1.0)
        ctx.setFillColor(white(s.a * 0.55))
        ctx.fill(CGRect(x: s.x - rayLen, y: cgY - rayWidth / 2,
                        width: rayLen * 2, height: rayWidth))
        ctx.fill(CGRect(x: s.x - rayWidth / 2, y: cgY - rayLen,
                        width: rayWidth, height: rayLen * 2))
    }

    // Bright core
    ctx.setFillColor(white(s.a))
    ctx.fillEllipse(in: CGRect(x: s.x - r, y: cgY - r, width: s.d, height: s.d))
}

for s in stars { drawStar(s) }

// --- 3) Wide moon halo (radial, behind the body) ---
let glowGradient = CGGradient(
    colorsSpace: sRGB,
    colors: [moonGlow, moonGlow.copy(alpha: 0.15)!, clear(moonGlow)] as CFArray,
    locations: [0.0, 0.5, 1.0]
)!
ctx.drawRadialGradient(
    glowGradient,
    startCenter: moonCenter, startRadius: moonR * 0.85,
    endCenter: moonCenter, endRadius: moonR * 1.65,
    options: []
)

// --- 4) Crescent moon body ---
// Geometry: outer disk MINUS inner disk, where inner is offset right.
// We use destinationOut inside a transparency layer so the inner cleanly
// subtracts. The naive even-odd fill of two overlapping circles produces
// a "ghost sliver" when one extends outside the other; this avoids that.
let outerRect = CGRect(
    x: moonCenter.x - moonR, y: moonCenter.y - moonR,
    width: moonR * 2, height: moonR * 2
)
let innerOffset: CGFloat = 110
let innerR: CGFloat = 240
let innerCenter = CGPoint(x: moonCenter.x + innerOffset, y: moonCenter.y)
let innerRect = CGRect(
    x: innerCenter.x - innerR, y: innerCenter.y - innerR,
    width: innerR * 2, height: innerR * 2
)

ctx.saveGState()
// Tight crescent-silhouette glow
ctx.setShadow(offset: .zero, blur: 50, color: moonShadow)
ctx.beginTransparencyLayer(auxiliaryInfo: nil)

// 4a) Solid outer disk
ctx.setFillColor(cream)
ctx.fillEllipse(in: outerRect)

// 4b) Subtract inner disk via destinationOut
ctx.setBlendMode(.destinationOut)
ctx.setFillColor(white(1.0)) // any opaque color works for destinationOut
ctx.fillEllipse(in: innerRect)
ctx.setBlendMode(.normal)

// 4c) Subtle dimensional shading: gradient from upper-left bright -> lower-right
// shadow. sourceAtop confines the gradient to the existing crescent silhouette.
ctx.setBlendMode(.sourceAtop)
let shadingGradient = CGGradient(
    colorsSpace: sRGB,
    colors: [clear(cream), creamShadow.copy(alpha: 0.45)!] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(
    shadingGradient,
    start: CGPoint(x: moonCenter.x - moonR * 0.5, y: moonCenter.y + moonR * 0.6),
    end:   CGPoint(x: moonCenter.x + moonR * 0.3, y: moonCenter.y - moonR * 0.7),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)
ctx.setBlendMode(.normal)

ctx.endTransparencyLayer()
ctx.restoreGState()

// --- 5) Encode and write PNG ---
guard let cgImage = ctx.makeImage() else {
    FileHandle.standardError.write(Data("error: makeImage() returned nil\n".utf8))
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let dest = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    FileHandle.standardError.write(Data("error: CGImageDestinationCreateWithURL failed\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(dest, cgImage, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("error: CGImageDestinationFinalize failed\n".utf8))
    exit(1)
}

print("Wrote \(Int(canvas))x\(Int(canvas)) PNG to \(outputPath)")
