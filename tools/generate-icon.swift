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

let topColor    = CGColor(red: 0.05, green: 0.05, blue: 0.17, alpha: 1.0)  // #0D0D2B
let bottomColor = CGColor(red: 0.20, green: 0.15, blue: 0.40, alpha: 1.0)  // #332666
let cream       = CGColor(red: 0.961, green: 0.937, blue: 0.847, alpha: 1.0)  // #F5EFD8
let creamGlow   = CGColor(red: 0.961, green: 0.937, blue: 0.847, alpha: 0.18)
func white(_ a: CGFloat) -> CGColor { CGColor(red: 1, green: 1, blue: 1, alpha: a) }

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

// 1) Background: vertical gradient (top dark navy -> bottom deep purple).
let gradient = CGGradient(
    colorsSpace: sRGB,
    colors: [topColor, bottomColor] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: canvas),  // visual top
    end:   CGPoint(x: 0, y: 0),       // visual bottom
    options: []
)

// 2) Stars (drawn before the moon glow so the glow sits on top).
struct Star { let x, y, d, a: CGFloat }
let stars: [Star] = [
    Star(x: 200, y: 200, d:  8, a: 0.55),
    Star(x: 320, y: 140, d: 12, a: 0.70),
    Star(x: 150, y: 360, d: 14, a: 0.50),
    Star(x: 820, y: 760, d:  8, a: 0.40),
    Star(x: 720, y: 880, d: 10, a: 0.60),
]
for s in stars {
    ctx.setFillColor(white(s.a))
    let r = s.d / 2
    ctx.fillEllipse(in: CGRect(x: s.x - r, y: flipY(s.y) - r, width: s.d, height: s.d))
}

// 3) Crescent moon with soft glow.
//    Outer circle minus inner circle, rendered inside a transparency layer so the
//    shadow follows the silhouette of the compound path (not each subpath).
ctx.setShadow(offset: .zero, blur: 60, color: creamGlow)
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.setFillColor(cream)

let outerCenter = CGPoint(x: 512, y: flipY(480))
let outerR: CGFloat = 265
let outerRect = CGRect(
    x: outerCenter.x - outerR, y: outerCenter.y - outerR,
    width: outerR * 2, height: outerR * 2
)

let innerCenter = CGPoint(x: 512 + 110, y: flipY(480))
let innerR: CGFloat = 230
let innerRect = CGRect(
    x: innerCenter.x - innerR, y: innerCenter.y - innerR,
    width: innerR * 2, height: innerR * 2
)

let crescent = CGMutablePath()
crescent.addEllipse(in: outerRect)
crescent.addEllipse(in: innerRect)
ctx.addPath(crescent)
ctx.fillPath(using: .evenOdd)

ctx.endTransparencyLayer()

// 4) Encode and write PNG.
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
