#!/usr/bin/env swift
//
// Dibuja el icono de Topo con CoreGraphics.
// Uso: swift Scripts/make-icon.swift <tamaño> <salida.png>
//
// Nota: a partir de macOS 26 el sistema aplica su propia máscara squircle, así
// que el lienzo se dibuja como un cuadrado totalmente opaco. Cualquier píxel
// transparente en las esquinas hace que macOS coloque el icono sobre una placa
// gris claro.
//
import AppKit
import CoreGraphics

let arguments = CommandLine.arguments
let size = arguments.count > 1 ? (Int(arguments[1]) ?? 1024) : 1024
let output = arguments.count > 2 ? arguments[2] : "icon.png"

// Todo se dibuja en un lienzo lógico de 1024 y luego se escala.
let canvas: CGFloat = 1024
let scale = CGFloat(size) / canvas

guard
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
else {
    FileHandle.standardError.write(Data("No se pudo crear el contexto\n".utf8))
    exit(1)
}

context.scaleBy(x: scale, y: scale)
context.setAllowsAntialiasing(true)
context.interpolationQuality = .high

// MARK: - Utilidades

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, a])!
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return rgba(r, g, b, alpha)
}

func fillEllipse(_ rect: CGRect, _ fill: CGColor) {
    context.setFillColor(fill)
    context.fillEllipse(in: rect)
}

func strokeArc(
    center: CGPoint,
    radius: CGFloat,
    from start: CGFloat,
    to end: CGFloat,
    width: CGFloat,
    _ stroke: CGColor
) {
    let path = CGMutablePath()
    path.addArc(
        center: center,
        radius: radius,
        startAngle: start,
        endAngle: end,
        clockwise: false
    )
    context.addPath(path)
    context.setStrokeColor(stroke)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.strokePath()
}

// MARK: - Fondo opaco

let tile = CGRect(x: 0, y: 0, width: canvas, height: canvas)

context.saveGState()
context.setFillColor(color(0x2FC88F))
context.fill(tile)
context.clip(to: tile)

let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0x3AD9A4), color(0x2FC0D8), color(0x2B7BFF)] as CFArray,
    locations: [0, 0.52, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 40, y: 1000),
    end: CGPoint(x: 990, y: 20),
    options: []
)

// Brillo superior suave.
let gloss = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [rgba(1, 1, 1, 0.26), rgba(1, 1, 1, 0.0)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gloss,
    start: CGPoint(x: 512, y: 1024),
    end: CGPoint(x: 512, y: 590),
    options: []
)

// MARK: - El topo

// Cuerpo/cabeza: domo que sale de la madriguera.
let head = CGRect(x: 286, y: 400, width: 452, height: 460)
fillEllipse(head, color(0x16253B))

// Hocico: óvalo más claro en el centro de la cara.
fillEllipse(CGRect(x: 464, y: 568, width: 96, height: 148), color(0x223A58))

// Ojos cerrados y tranquilos.
strokeArc(
    center: CGPoint(x: 438, y: 708),
    radius: 34,
    from: .pi * 1.17,
    to: .pi * 1.83,
    width: 15,
    rgba(1, 1, 1, 0.95)
)
strokeArc(
    center: CGPoint(x: 586, y: 708),
    radius: 34,
    from: .pi * 1.17,
    to: .pi * 1.83,
    width: 15,
    rgba(1, 1, 1, 0.95)
)

// Nariz rosada en la punta del hocico.
fillEllipse(CGRect(x: 490, y: 562, width: 48, height: 40), color(0xFF93AC))
fillEllipse(CGRect(x: 505, y: 590, width: 18, height: 10), rgba(1, 1, 1, 0.22))

// MARK: - Montículo (tapa la parte baja del cuerpo)

let mound = CGMutablePath()
mound.move(to: CGPoint(x: -60, y: -60))
mound.addLine(to: CGPoint(x: -60, y: 120))
mound.addCurve(
    to: CGPoint(x: 512, y: 522),
    control1: CGPoint(x: 170, y: 478),
    control2: CGPoint(x: 372, y: 522)
)
mound.addCurve(
    to: CGPoint(x: 1084, y: 190),
    control1: CGPoint(x: 652, y: 522),
    control2: CGPoint(x: 854, y: 478)
)
mound.addLine(to: CGPoint(x: 1084, y: -60))
mound.closeSubpath()

// Opaco: se rellena con el mismo degradado aclarado, para que el cuerpo no se
// transparente por debajo y el topo parezca salir de verdad.
context.saveGState()
context.addPath(mound)
context.clip()
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 40, y: 1000),
    end: CGPoint(x: 990, y: 20),
    options: []
)
context.setFillColor(rgba(1, 1, 1, 0.26))
context.fill(tile)
context.restoreGState()

// Sombra de contacto del cuerpo sobre el montículo.
context.saveGState()
context.addPath(mound)
context.clip()
fillEllipse(CGRect(x: 262, y: 440, width: 500, height: 120), rgba(0, 0.15, 0.35, 0.16))
context.restoreGState()

// Borde superior del montículo.
context.saveGState()
context.addPath(mound)
context.clip(to: CGRect(x: 0, y: 420, width: canvas, height: 160))
context.setStrokeColor(rgba(1, 1, 1, 0.30))
context.setLineWidth(4)
context.strokePath()
context.restoreGState()

// MARK: - Patas apoyadas en el montículo

func paw(center: CGPoint, angle: CGFloat) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: angle)

    let rect = CGRect(x: -58, y: -40, width: 116, height: 80)
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: 44,
        cornerHeight: 44,
        transform: nil
    )
    context.addPath(path)
    context.setFillColor(color(0x16253B))
    context.fillPath()

    // Uñas: tres muescas claras.
    context.setStrokeColor(rgba(1, 1, 1, 0.38))
    context.setLineWidth(7)
    context.setLineCap(.round)
    for offset in [-24.0, 0.0, 24.0] {
        context.move(to: CGPoint(x: offset, y: -34))
        context.addLine(to: CGPoint(x: offset, y: -20))
    }
    context.strokePath()

    context.restoreGState()
}

paw(center: CGPoint(x: 372, y: 508), angle: 0.24)
paw(center: CGPoint(x: 652, y: 508), angle: -0.24)

context.restoreGState()

// MARK: - Guardar

guard let image = context.makeImage() else {
    FileHandle.standardError.write(Data("No se pudo generar la imagen\n".utf8))
    exit(1)
}

let representation = NSBitmapImageRep(cgImage: image)
guard let data = representation.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("No se pudo codificar el PNG\n".utf8))
    exit(1)
}

do {
    try data.write(to: URL(fileURLWithPath: output))
} catch {
    FileHandle.standardError.write(Data("No se pudo escribir \(output): \(error)\n".utf8))
    exit(1)
}
