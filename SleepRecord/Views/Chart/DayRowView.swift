import SwiftUI

struct DayRowView: View {
    let date: Date
    let cells: [ChartCell]
    let notes: String
    let dateLabelWidth: CGFloat
    let notesWidth: CGFloat
    let rowHeight: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text(date, formatter: TimeFormatter.dateLabel)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: dateLabelWidth, alignment: .trailing)
                .padding(.trailing, 4)

            GeometryReader { geo in
                let w = geo.size.width / 24
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { h in
                            CellView(cell: cells[h])
                                .frame(width: w, height: rowHeight)
                        }
                    }
                    Rectangle().fill(.black)
                        .frame(width: 1.5, height: rowHeight)
                        .offset(x: w * 12)
                }
            }
            .frame(height: rowHeight)

            Text(notes)
                .font(.system(size: 9))
                .foregroundStyle(notes.isEmpty ? .clear : .primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(width: notesWidth, height: rowHeight, alignment: .topLeading)
                .padding(.leading, 4)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 0.4))
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
