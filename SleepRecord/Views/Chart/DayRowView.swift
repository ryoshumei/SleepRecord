import SwiftUI

struct DayRowView: View {
    let date: Date
    let cells: [ChartCell]

    var body: some View {
        HStack(spacing: 0) {
            Text(date, formatter: TimeFormatter.dateLabel)
                .font(.caption2)
                .frame(width: 56, alignment: .trailing)
                .padding(.trailing, 4)
            GeometryReader { geo in
                let w = geo.size.width / 24
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { h in
                            CellView(cell: cells[h])
                                .frame(width: w, height: 28)
                        }
                    }
                    Rectangle().fill(.black).frame(width: 1.5)
                        .offset(x: w * 12, y: 0).frame(height: 28)
                }
            }
            .frame(height: 28)
        }
    }
}

private struct CellView: View {
    let cell: ChartCell

    var body: some View {
        ZStack {
            Rectangle().stroke(Color.black, lineWidth: 0.4)
            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(.white)
                    if cell.asleep {
                        DiagonalHatch().fill(.black)
                    }
                }
                Rectangle().fill(cell.inBed ? Color(red: 0.9, green: 0.22, blue: 0.27) : .white)
            }
        }
    }
}

private struct DiagonalHatch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 3
        var x = -rect.height
        while x < rect.width + rect.height {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + 1, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + 1 + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.closeSubpath()
            x += spacing
        }
        return path
    }
}
