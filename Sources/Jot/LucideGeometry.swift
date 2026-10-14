// Generated from the pinned Lucide package by Editor/generate-icons.mjs. Do not edit.
import CoreGraphics

enum LucideGeometry {
    static let controlSize: CGFloat = 16
    static let strokeWidth: CGFloat = 1.5
    static let viewBox: CGFloat = 24
    static let paths: [String: CGPath] = makePaths()

    private static func makePaths() -> [String: CGPath] {
        var result: [String: CGPath] = [:]
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 12, y: 5))
            path.addLine(to: CGPoint(x: 12, y: 19))
            path.move(to: CGPoint(x: 19, y: 12))
            path.addLine(to: CGPoint(x: 12, y: 19))
            path.addLine(to: CGPoint(x: 5, y: 12))
            result["arrow-down"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 12, y: 19))
            path.addLine(to: CGPoint(x: 5, y: 12))
            path.addLine(to: CGPoint(x: 12, y: 5))
            path.move(to: CGPoint(x: 19, y: 12))
            path.addLine(to: CGPoint(x: 5, y: 12))
            result["arrow-left"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 5, y: 12))
            path.addLine(to: CGPoint(x: 12, y: 5))
            path.addLine(to: CGPoint(x: 19, y: 12))
            path.move(to: CGPoint(x: 12, y: 19))
            path.addLine(to: CGPoint(x: 12, y: 5))
            result["arrow-up"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 6, y: 12))
            path.addLine(to: CGPoint(x: 15, y: 12))
            path.addCurve(to: CGPoint(x: 19, y: 16), control1: CGPoint(x: 17.209139, y: 12), control2: CGPoint(x: 19, y: 13.790861))
            path.addCurve(to: CGPoint(x: 15, y: 20), control1: CGPoint(x: 19, y: 18.209139), control2: CGPoint(x: 17.209139, y: 20))
            path.addLine(to: CGPoint(x: 7, y: 20))
            path.addCurve(to: CGPoint(x: 6, y: 19), control1: CGPoint(x: 6.447715, y: 20), control2: CGPoint(x: 6, y: 19.552285))
            path.addLine(to: CGPoint(x: 6, y: 5))
            path.addCurve(to: CGPoint(x: 7, y: 4), control1: CGPoint(x: 6, y: 4.447715), control2: CGPoint(x: 6.447715, y: 4))
            path.addLine(to: CGPoint(x: 14, y: 4))
            path.addCurve(to: CGPoint(x: 18, y: 8), control1: CGPoint(x: 16.209139, y: 4), control2: CGPoint(x: 18, y: 5.790861))
            path.addCurve(to: CGPoint(x: 14, y: 12), control1: CGPoint(x: 18, y: 10.209139), control2: CGPoint(x: 16.209139, y: 12))
            result["bold"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 20, y: 6))
            path.addLine(to: CGPoint(x: 9, y: 17))
            path.addLine(to: CGPoint(x: 4, y: 12))
            result["check"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 6, y: 9))
            path.addLine(to: CGPoint(x: 12, y: 15))
            path.addLine(to: CGPoint(x: 18, y: 9))
            result["chevron-down"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))
            path.move(to: CGPoint(x: 15, y: 9))
            path.addLine(to: CGPoint(x: 9, y: 15))
            path.move(to: CGPoint(x: 9, y: 9))
            path.addLine(to: CGPoint(x: 15, y: 15))
            result["circle-x"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 16, y: 18))
            path.addLine(to: CGPoint(x: 22, y: 12))
            path.addLine(to: CGPoint(x: 16, y: 6))
            path.move(to: CGPoint(x: 8, y: 6))
            path.addLine(to: CGPoint(x: 2, y: 12))
            path.addLine(to: CGPoint(x: 8, y: 18))
            result["code"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 12, y: 15))
            path.addLine(to: CGPoint(x: 12, y: 3))
            path.move(to: CGPoint(x: 21, y: 15))
            path.addLine(to: CGPoint(x: 21, y: 19))
            path.addCurve(to: CGPoint(x: 19, y: 21), control1: CGPoint(x: 21, y: 20.104569), control2: CGPoint(x: 20.104569, y: 21))
            path.addLine(to: CGPoint(x: 5, y: 21))
            path.addCurve(to: CGPoint(x: 3, y: 19), control1: CGPoint(x: 3.895431, y: 21), control2: CGPoint(x: 3, y: 20.104569))
            path.addLine(to: CGPoint(x: 3, y: 15))
            path.move(to: CGPoint(x: 7, y: 10))
            path.addLine(to: CGPoint(x: 12, y: 15))
            path.addLine(to: CGPoint(x: 17, y: 10))
            result["download"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: 11, y: 11, width: 2, height: 2))
            path.addEllipse(in: CGRect(x: 18, y: 11, width: 2, height: 2))
            path.addEllipse(in: CGRect(x: 4, y: 11, width: 2, height: 2))
            result["ellipsis"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 6, y: 22))
            path.addCurve(to: CGPoint(x: 4, y: 20), control1: CGPoint(x: 4.895431, y: 22), control2: CGPoint(x: 4, y: 21.104569))
            path.addLine(to: CGPoint(x: 4, y: 4))
            path.addCurve(to: CGPoint(x: 6, y: 2), control1: CGPoint(x: 4, y: 2.895431), control2: CGPoint(x: 4.895431, y: 2))
            path.addLine(to: CGPoint(x: 14, y: 2))
            path.addCurve(to: CGPoint(x: 15.704, y: 2.706), control1: CGPoint(x: 14.639365, y: 1.998964), control2: CGPoint(x: 15.252715, y: 2.253086))
            path.addLine(to: CGPoint(x: 19.292, y: 6.294))
            path.addCurve(to: CGPoint(x: 20, y: 8), control1: CGPoint(x: 19.74614, y: 6.745444), control2: CGPoint(x: 20.00104, y: 7.359653))
            path.addLine(to: CGPoint(x: 20, y: 20))
            path.addCurve(to: CGPoint(x: 18, y: 22), control1: CGPoint(x: 20, y: 21.104569), control2: CGPoint(x: 19.104569, y: 22))
            path.closeSubpath()
            path.move(to: CGPoint(x: 14, y: 2))
            path.addLine(to: CGPoint(x: 14, y: 7))
            path.addCurve(to: CGPoint(x: 15, y: 8), control1: CGPoint(x: 14, y: 7.552285), control2: CGPoint(x: 14.447715, y: 8))
            path.addLine(to: CGPoint(x: 20, y: 8))
            path.move(to: CGPoint(x: 10, y: 9))
            path.addLine(to: CGPoint(x: 8, y: 9))
            path.move(to: CGPoint(x: 16, y: 13))
            path.addLine(to: CGPoint(x: 8, y: 13))
            path.move(to: CGPoint(x: 16, y: 17))
            path.addLine(to: CGPoint(x: 8, y: 17))
            result["file-text"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 15, y: 6))
            path.addLine(to: CGPoint(x: 15, y: 18))
            path.addCurve(to: CGPoint(x: 18, y: 21), control1: CGPoint(x: 15, y: 19.656854), control2: CGPoint(x: 16.343146, y: 21))
            path.addCurve(to: CGPoint(x: 21, y: 18), control1: CGPoint(x: 19.656854, y: 21), control2: CGPoint(x: 21, y: 19.656854))
            path.addCurve(to: CGPoint(x: 18, y: 15), control1: CGPoint(x: 21, y: 16.343146), control2: CGPoint(x: 19.656854, y: 15))
            path.addLine(to: CGPoint(x: 6, y: 15))
            path.addCurve(to: CGPoint(x: 3, y: 18), control1: CGPoint(x: 4.343146, y: 15), control2: CGPoint(x: 3, y: 16.343146))
            path.addCurve(to: CGPoint(x: 6, y: 21), control1: CGPoint(x: 3, y: 19.656854), control2: CGPoint(x: 4.343146, y: 21))
            path.addCurve(to: CGPoint(x: 9, y: 18), control1: CGPoint(x: 7.656854, y: 21), control2: CGPoint(x: 9, y: 19.656854))
            path.addLine(to: CGPoint(x: 9, y: 6))
            path.addCurve(to: CGPoint(x: 6, y: 3), control1: CGPoint(x: 9, y: 4.343146), control2: CGPoint(x: 7.656854, y: 3))
            path.addCurve(to: CGPoint(x: 3, y: 6), control1: CGPoint(x: 4.343146, y: 3), control2: CGPoint(x: 3, y: 4.343146))
            path.addCurve(to: CGPoint(x: 6, y: 9), control1: CGPoint(x: 3, y: 7.656854), control2: CGPoint(x: 4.343146, y: 9))
            path.addLine(to: CGPoint(x: 18, y: 9))
            path.addCurve(to: CGPoint(x: 21, y: 6), control1: CGPoint(x: 19.656854, y: 9), control2: CGPoint(x: 21, y: 7.656854))
            path.addCurve(to: CGPoint(x: 18, y: 3), control1: CGPoint(x: 21, y: 4.343146), control2: CGPoint(x: 19.656854, y: 3))
            path.addCurve(to: CGPoint(x: 15, y: 6), control1: CGPoint(x: 16.343146, y: 3), control2: CGPoint(x: 15, y: 4.343146))
            result["command"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 2, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 6))
            path.move(to: CGPoint(x: 2, y: 10))
            path.addLine(to: CGPoint(x: 6, y: 10))
            path.move(to: CGPoint(x: 2, y: 14))
            path.addLine(to: CGPoint(x: 6, y: 14))
            path.move(to: CGPoint(x: 2, y: 18))
            path.addLine(to: CGPoint(x: 6, y: 18))
            path.addRoundedRect(in: CGRect(x: 4, y: 2, width: 16, height: 20), cornerWidth: 2, cornerHeight: 2)
            path.move(to: CGPoint(x: 9.5, y: 8))
            path.addLine(to: CGPoint(x: 14.5, y: 8))
            path.move(to: CGPoint(x: 9.5, y: 12))
            path.addLine(to: CGPoint(x: 16, y: 12))
            path.move(to: CGPoint(x: 9.5, y: 16))
            path.addLine(to: CGPoint(x: 14, y: 16))
            result["notebook-text"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 5, y: 12))
            path.addLine(to: CGPoint(x: 19, y: 12))
            path.move(to: CGPoint(x: 12, y: 5))
            path.addLine(to: CGPoint(x: 12, y: 19))
            result["plus"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 14, y: 17))
            path.addLine(to: CGPoint(x: 5, y: 17))
            path.move(to: CGPoint(x: 19, y: 7))
            path.addLine(to: CGPoint(x: 10, y: 7))
            path.addEllipse(in: CGRect(x: 14, y: 14, width: 6, height: 6))
            path.addEllipse(in: CGRect(x: 4, y: 4, width: 6, height: 6))
            result["settings-2"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 12, y: 4))
            path.addLine(to: CGPoint(x: 12, y: 20))
            path.move(to: CGPoint(x: 4, y: 7))
            path.addLine(to: CGPoint(x: 4, y: 5))
            path.addCurve(to: CGPoint(x: 5, y: 4), control1: CGPoint(x: 4, y: 4.447715), control2: CGPoint(x: 4.447715, y: 4))
            path.addLine(to: CGPoint(x: 19, y: 4))
            path.addCurve(to: CGPoint(x: 20, y: 5), control1: CGPoint(x: 19.552285, y: 4), control2: CGPoint(x: 20, y: 4.447715))
            path.addLine(to: CGPoint(x: 20, y: 7))
            path.move(to: CGPoint(x: 9, y: 20))
            path.addLine(to: CGPoint(x: 15, y: 20))
            result["type"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: 2, y: 2, width: 20, height: 20))
            path.move(to: CGPoint(x: 12, y: 16))
            path.addLine(to: CGPoint(x: 12, y: 12))
            path.move(to: CGPoint(x: 12, y: 8))
            path.addLine(to: CGPoint(x: 12.01, y: 8))
            result["info"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 19, y: 4))
            path.addLine(to: CGPoint(x: 10, y: 4))
            path.move(to: CGPoint(x: 14, y: 20))
            path.addLine(to: CGPoint(x: 5, y: 20))
            path.move(to: CGPoint(x: 15, y: 4))
            path.addLine(to: CGPoint(x: 9, y: 20))
            result["italic"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 10, y: 13))
            path.addCurve(to: CGPoint(x: 13.64665, y: 14.992333), control1: CGPoint(x: 10.868955, y: 14.161693), control2: CGPoint(x: 12.199627, y: 14.8887))
            path.addCurve(to: CGPoint(x: 17.54, y: 13.54), control1: CGPoint(x: 15.093672, y: 15.095966), control2: CGPoint(x: 16.514366, y: 14.566006))
            path.addLine(to: CGPoint(x: 20.54, y: 10.54))
            path.addCurve(to: CGPoint(x: 20.479093, y: 3.530907), control1: CGPoint(x: 22.434861, y: 8.578106), control2: CGPoint(x: 22.407762, y: 5.459576))
            path.addCurve(to: CGPoint(x: 13.47, y: 3.47), control1: CGPoint(x: 18.550424, y: 1.602238), control2: CGPoint(x: 15.431894, y: 1.575139))
            path.addLine(to: CGPoint(x: 11.75, y: 5.18))
            path.move(to: CGPoint(x: 14, y: 11))
            path.addCurve(to: CGPoint(x: 10.35335, y: 9.007667), control1: CGPoint(x: 13.131045, y: 9.838307), control2: CGPoint(x: 11.800373, y: 9.1113))
            path.addCurve(to: CGPoint(x: 6.46, y: 10.46), control1: CGPoint(x: 8.906328, y: 8.904034), control2: CGPoint(x: 7.485634, y: 9.433994))
            path.addLine(to: CGPoint(x: 3.46, y: 13.46))
            path.addCurve(to: CGPoint(x: 3.520907, y: 20.469093), control1: CGPoint(x: 1.565139, y: 15.421894), control2: CGPoint(x: 1.592238, y: 18.540424))
            path.addCurve(to: CGPoint(x: 10.53, y: 20.53), control1: CGPoint(x: 5.449576, y: 22.397762), control2: CGPoint(x: 8.568106, y: 22.424861))
            path.addLine(to: CGPoint(x: 12.24, y: 18.82))
            result["link"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 3, y: 5))
            path.addLine(to: CGPoint(x: 3.01, y: 5))
            path.move(to: CGPoint(x: 3, y: 12))
            path.addLine(to: CGPoint(x: 3.01, y: 12))
            path.move(to: CGPoint(x: 3, y: 19))
            path.addLine(to: CGPoint(x: 3.01, y: 19))
            path.move(to: CGPoint(x: 8, y: 5))
            path.addLine(to: CGPoint(x: 21, y: 5))
            path.move(to: CGPoint(x: 8, y: 12))
            path.addLine(to: CGPoint(x: 21, y: 12))
            path.move(to: CGPoint(x: 8, y: 19))
            path.addLine(to: CGPoint(x: 21, y: 19))
            result["list"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 11, y: 5))
            path.addLine(to: CGPoint(x: 21, y: 5))
            path.move(to: CGPoint(x: 11, y: 12))
            path.addLine(to: CGPoint(x: 21, y: 12))
            path.move(to: CGPoint(x: 11, y: 19))
            path.addLine(to: CGPoint(x: 21, y: 19))
            path.move(to: CGPoint(x: 4, y: 4))
            path.addLine(to: CGPoint(x: 5, y: 4))
            path.addLine(to: CGPoint(x: 5, y: 9))
            path.move(to: CGPoint(x: 4, y: 9))
            path.addLine(to: CGPoint(x: 6, y: 9))
            path.move(to: CGPoint(x: 6.5, y: 20))
            path.addLine(to: CGPoint(x: 3.4, y: 20))
            path.addCurve(to: CGPoint(x: 6, y: 16.5), control1: CGPoint(x: 3.4, y: 19), control2: CGPoint(x: 6, y: 18.075))
            path.addCurve(to: CGPoint(x: 5.047814, y: 15.103416), control1: CGPoint(x: 6.000081, y: 15.882933), control2: CGPoint(x: 5.622258, y: 15.328774))
            path.addCurve(to: CGPoint(x: 3.4, y: 15.48), control1: CGPoint(x: 4.47337, y: 14.878057), control2: CGPoint(x: 3.819525, y: 15.027484))
            result["list-ordered"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 13, y: 5))
            path.addLine(to: CGPoint(x: 21, y: 5))
            path.move(to: CGPoint(x: 13, y: 12))
            path.addLine(to: CGPoint(x: 21, y: 12))
            path.move(to: CGPoint(x: 13, y: 19))
            path.addLine(to: CGPoint(x: 21, y: 19))
            path.move(to: CGPoint(x: 3, y: 17))
            path.addLine(to: CGPoint(x: 5, y: 19))
            path.addLine(to: CGPoint(x: 9, y: 15))
            path.addRoundedRect(in: CGRect(x: 3, y: 4, width: 6, height: 6), cornerWidth: 1, cornerHeight: 1)
            result["list-todo"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 15, y: 3))
            path.addLine(to: CGPoint(x: 21, y: 3))
            path.addLine(to: CGPoint(x: 21, y: 9))
            path.move(to: CGPoint(x: 21, y: 3))
            path.addLine(to: CGPoint(x: 14, y: 10))
            path.move(to: CGPoint(x: 3, y: 21))
            path.addLine(to: CGPoint(x: 10, y: 14))
            path.move(to: CGPoint(x: 9, y: 21))
            path.addLine(to: CGPoint(x: 3, y: 21))
            path.addLine(to: CGPoint(x: 3, y: 15))
            result["maximize-2"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 14, y: 10))
            path.addLine(to: CGPoint(x: 21, y: 3))
            path.move(to: CGPoint(x: 20, y: 10))
            path.addLine(to: CGPoint(x: 14, y: 10))
            path.addLine(to: CGPoint(x: 14, y: 4))
            path.move(to: CGPoint(x: 3, y: 21))
            path.addLine(to: CGPoint(x: 10, y: 14))
            path.move(to: CGPoint(x: 4, y: 14))
            path.addLine(to: CGPoint(x: 10, y: 14))
            path.addLine(to: CGPoint(x: 10, y: 20))
            result["minimize-2"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.addRoundedRect(in: CGRect(x: 3, y: 3, width: 18, height: 18), cornerWidth: 2, cornerHeight: 2)
            path.move(to: CGPoint(x: 9, y: 3))
            path.addLine(to: CGPoint(x: 9, y: 21))
            result["panel-left"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 12, y: 17))
            path.addLine(to: CGPoint(x: 12, y: 22))
            path.move(to: CGPoint(x: 9, y: 10.76))
            path.addCurve(to: CGPoint(x: 7.89, y: 12.55), control1: CGPoint(x: 8.999597, y: 11.518944), control2: CGPoint(x: 8.569658, y: 12.21227))
            path.addLine(to: CGPoint(x: 6.11, y: 13.45))
            path.addCurve(to: CGPoint(x: 5, y: 15.24), control1: CGPoint(x: 5.430342, y: 13.78773), control2: CGPoint(x: 5.000403, y: 14.481056))
            path.addLine(to: CGPoint(x: 5, y: 16))
            path.addCurve(to: CGPoint(x: 6, y: 17), control1: CGPoint(x: 5, y: 16.552285), control2: CGPoint(x: 5.447715, y: 17))
            path.addLine(to: CGPoint(x: 18, y: 17))
            path.addCurve(to: CGPoint(x: 19, y: 16), control1: CGPoint(x: 18.552285, y: 17), control2: CGPoint(x: 19, y: 16.552285))
            path.addLine(to: CGPoint(x: 19, y: 15.24))
            path.addCurve(to: CGPoint(x: 17.89, y: 13.45), control1: CGPoint(x: 18.999597, y: 14.481056), control2: CGPoint(x: 18.569658, y: 13.78773))
            path.addLine(to: CGPoint(x: 16.11, y: 12.55))
            path.addCurve(to: CGPoint(x: 15, y: 10.76), control1: CGPoint(x: 15.430342, y: 12.21227), control2: CGPoint(x: 15.000403, y: 11.518944))
            path.addLine(to: CGPoint(x: 15, y: 7))
            path.addCurve(to: CGPoint(x: 16, y: 6), control1: CGPoint(x: 15, y: 6.447715), control2: CGPoint(x: 15.447715, y: 6))
            path.addCurve(to: CGPoint(x: 18, y: 4), control1: CGPoint(x: 17.104569, y: 6), control2: CGPoint(x: 18, y: 5.104569))
            path.addCurve(to: CGPoint(x: 16, y: 2), control1: CGPoint(x: 18, y: 2.895431), control2: CGPoint(x: 17.104569, y: 2))
            path.addLine(to: CGPoint(x: 8, y: 2))
            path.addCurve(to: CGPoint(x: 6, y: 4), control1: CGPoint(x: 6.895431, y: 2), control2: CGPoint(x: 6, y: 2.895431))
            path.addCurve(to: CGPoint(x: 8, y: 6), control1: CGPoint(x: 6, y: 5.104569), control2: CGPoint(x: 6.895431, y: 6))
            path.addCurve(to: CGPoint(x: 9, y: 7), control1: CGPoint(x: 8.552285, y: 6), control2: CGPoint(x: 9, y: 6.447715))
            path.closeSubpath()
            result["pin"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 12, y: 17))
            path.addLine(to: CGPoint(x: 12, y: 22))
            path.move(to: CGPoint(x: 15, y: 9.34))
            path.addLine(to: CGPoint(x: 15, y: 7))
            path.addCurve(to: CGPoint(x: 16, y: 6), control1: CGPoint(x: 15, y: 6.447715), control2: CGPoint(x: 15.447715, y: 6))
            path.addCurve(to: CGPoint(x: 18, y: 4), control1: CGPoint(x: 17.104569, y: 6), control2: CGPoint(x: 18, y: 5.104569))
            path.addCurve(to: CGPoint(x: 16, y: 2), control1: CGPoint(x: 18, y: 2.895431), control2: CGPoint(x: 17.104569, y: 2))
            path.addLine(to: CGPoint(x: 7.89, y: 2))
            path.move(to: CGPoint(x: 2, y: 2))
            path.addLine(to: CGPoint(x: 22, y: 22))
            path.move(to: CGPoint(x: 9, y: 9))
            path.addLine(to: CGPoint(x: 9, y: 10.76))
            path.addCurve(to: CGPoint(x: 7.89, y: 12.55), control1: CGPoint(x: 8.999597, y: 11.518944), control2: CGPoint(x: 8.569658, y: 12.21227))
            path.addLine(to: CGPoint(x: 6.11, y: 13.45))
            path.addCurve(to: CGPoint(x: 5, y: 15.24), control1: CGPoint(x: 5.430342, y: 13.78773), control2: CGPoint(x: 5.000403, y: 14.481056))
            path.addLine(to: CGPoint(x: 5, y: 16))
            path.addCurve(to: CGPoint(x: 6, y: 17), control1: CGPoint(x: 5, y: 16.552285), control2: CGPoint(x: 5.447715, y: 17))
            path.addLine(to: CGPoint(x: 17, y: 17))
            result["pin-off"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 15, y: 14))
            path.addLine(to: CGPoint(x: 20, y: 9))
            path.addLine(to: CGPoint(x: 15, y: 4))
            path.move(to: CGPoint(x: 20, y: 9))
            path.addLine(to: CGPoint(x: 9.5, y: 9))
            path.addCurve(to: CGPoint(x: 4, y: 14.5), control1: CGPoint(x: 6.462434, y: 9), control2: CGPoint(x: 4, y: 11.462434))
            path.addCurve(to: CGPoint(x: 9.5, y: 20), control1: CGPoint(x: 4, y: 17.537566), control2: CGPoint(x: 6.462434, y: 20))
            path.addLine(to: CGPoint(x: 13, y: 20))
            result["redo-2"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 21, y: 21))
            path.addLine(to: CGPoint(x: 16.66, y: 16.66))
            path.addEllipse(in: CGRect(x: 3, y: 3, width: 16, height: 16))
            result["search"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 10, y: 9))
            path.addLine(to: CGPoint(x: 7, y: 12))
            path.addLine(to: CGPoint(x: 10, y: 15))
            path.move(to: CGPoint(x: 14, y: 15))
            path.addLine(to: CGPoint(x: 17, y: 12))
            path.addLine(to: CGPoint(x: 14, y: 9))
            path.addRoundedRect(in: CGRect(x: 3, y: 3, width: 18, height: 18), cornerWidth: 2, cornerHeight: 2)
            result["square-code"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 12, y: 3))
            path.addLine(to: CGPoint(x: 5, y: 3))
            path.addCurve(to: CGPoint(x: 3, y: 5), control1: CGPoint(x: 3.895431, y: 3), control2: CGPoint(x: 3, y: 3.895431))
            path.addLine(to: CGPoint(x: 3, y: 19))
            path.addCurve(to: CGPoint(x: 5, y: 21), control1: CGPoint(x: 3, y: 20.104569), control2: CGPoint(x: 3.895431, y: 21))
            path.addLine(to: CGPoint(x: 19, y: 21))
            path.addCurve(to: CGPoint(x: 21, y: 19), control1: CGPoint(x: 20.104569, y: 21), control2: CGPoint(x: 21, y: 20.104569))
            path.addLine(to: CGPoint(x: 21, y: 12))
            path.move(to: CGPoint(x: 18.375, y: 2.625))
            path.addCurve(to: CGPoint(x: 21.375, y: 2.625), control1: CGPoint(x: 19.203427, y: 1.796573), control2: CGPoint(x: 20.546573, y: 1.796573))
            path.addCurve(to: CGPoint(x: 21.375, y: 5.625), control1: CGPoint(x: 22.203427, y: 3.453427), control2: CGPoint(x: 22.203427, y: 4.796573))
            path.addLine(to: CGPoint(x: 12.362, y: 14.639))
            path.addCurve(to: CGPoint(x: 11.509, y: 15.144), control1: CGPoint(x: 12.124549, y: 14.876246), control2: CGPoint(x: 11.831206, y: 15.049914))
            path.addLine(to: CGPoint(x: 8.636, y: 15.984))
            path.addCurve(to: CGPoint(x: 8.142447, y: 15.857553), control1: CGPoint(x: 8.460735, y: 16.035119), control2: CGPoint(x: 8.271541, y: 15.986648))
            path.addCurve(to: CGPoint(x: 8.016, y: 15.364), control1: CGPoint(x: 8.013352, y: 15.728459), control2: CGPoint(x: 7.964881, y: 15.539265))
            path.addLine(to: CGPoint(x: 8.856, y: 12.491))
            path.addCurve(to: CGPoint(x: 9.362, y: 11.639), control1: CGPoint(x: 8.950526, y: 12.169051), control2: CGPoint(x: 9.124534, y: 11.876058))
            path.closeSubpath()
            result["square-pen"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 16, y: 4))
            path.addLine(to: CGPoint(x: 9, y: 4))
            path.addCurve(to: CGPoint(x: 6.549391, y: 5.267307), control1: CGPoint(x: 8.025818, y: 3.999489), control2: CGPoint(x: 7.112044, y: 4.472038))
            path.addCurve(to: CGPoint(x: 6.17, y: 8), control1: CGPoint(x: 5.986738, y: 6.062576), control2: CGPoint(x: 5.845272, y: 7.081532))
            path.move(to: CGPoint(x: 14, y: 12))
            path.addCurve(to: CGPoint(x: 18, y: 16), control1: CGPoint(x: 16.209139, y: 12), control2: CGPoint(x: 18, y: 13.790861))
            path.addCurve(to: CGPoint(x: 14, y: 20), control1: CGPoint(x: 18, y: 18.209139), control2: CGPoint(x: 16.209139, y: 20))
            path.addLine(to: CGPoint(x: 6, y: 20))
            path.move(to: CGPoint(x: 4, y: 12))
            path.addLine(to: CGPoint(x: 20, y: 12))
            result["strikethrough"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 10, y: 11))
            path.addLine(to: CGPoint(x: 10, y: 17))
            path.move(to: CGPoint(x: 14, y: 11))
            path.addLine(to: CGPoint(x: 14, y: 17))
            path.move(to: CGPoint(x: 19, y: 6))
            path.addLine(to: CGPoint(x: 19, y: 20))
            path.addCurve(to: CGPoint(x: 17, y: 22), control1: CGPoint(x: 19, y: 21.104569), control2: CGPoint(x: 18.104569, y: 22))
            path.addLine(to: CGPoint(x: 7, y: 22))
            path.addCurve(to: CGPoint(x: 5, y: 20), control1: CGPoint(x: 5.895431, y: 22), control2: CGPoint(x: 5, y: 21.104569))
            path.addLine(to: CGPoint(x: 5, y: 6))
            path.move(to: CGPoint(x: 3, y: 6))
            path.addLine(to: CGPoint(x: 21, y: 6))
            path.move(to: CGPoint(x: 8, y: 6))
            path.addLine(to: CGPoint(x: 8, y: 4))
            path.addCurve(to: CGPoint(x: 10, y: 2), control1: CGPoint(x: 8, y: 2.895431), control2: CGPoint(x: 8.895431, y: 2))
            path.addLine(to: CGPoint(x: 14, y: 2))
            path.addCurve(to: CGPoint(x: 16, y: 4), control1: CGPoint(x: 15.104569, y: 2), control2: CGPoint(x: 16, y: 2.895431))
            path.addLine(to: CGPoint(x: 16, y: 6))
            result["trash-2"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 21.73, y: 18))
            path.addLine(to: CGPoint(x: 13.73, y: 4))
            path.addCurve(to: CGPoint(x: 11.99, y: 2.986103), control1: CGPoint(x: 13.374878, y: 3.373379), control2: CGPoint(x: 12.710254, y: 2.986103))
            path.addCurve(to: CGPoint(x: 10.25, y: 4), control1: CGPoint(x: 11.269746, y: 2.986103), control2: CGPoint(x: 10.605122, y: 3.373379))
            path.addLine(to: CGPoint(x: 2.25, y: 18))
            path.addCurve(to: CGPoint(x: 2.254446, y: 20.007823), control1: CGPoint(x: 1.891089, y: 18.621585), control2: CGPoint(x: 1.892786, y: 19.387834))
            path.addCurve(to: CGPoint(x: 4, y: 21), control1: CGPoint(x: 2.616107, y: 20.627812), control2: CGPoint(x: 3.282265, y: 21.006458))
            path.addLine(to: CGPoint(x: 20, y: 21))
            path.addCurve(to: CGPoint(x: 21.730513, y: 19.999113), control1: CGPoint(x: 20.714165, y: 20.999268), control2: CGPoint(x: 21.373748, y: 20.617781))
            path.addCurve(to: CGPoint(x: 21.73, y: 18), control1: CGPoint(x: 22.087279, y: 19.380444), control2: CGPoint(x: 22.087083, y: 18.618485))
            path.move(to: CGPoint(x: 12, y: 9))
            path.addLine(to: CGPoint(x: 12, y: 13))
            path.move(to: CGPoint(x: 12, y: 17))
            path.addLine(to: CGPoint(x: 12.01, y: 17))
            result["triangle-alert"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 9, y: 14))
            path.addLine(to: CGPoint(x: 4, y: 9))
            path.addLine(to: CGPoint(x: 9, y: 4))
            path.move(to: CGPoint(x: 4, y: 9))
            path.addLine(to: CGPoint(x: 14.5, y: 9))
            path.addCurve(to: CGPoint(x: 20, y: 14.5), control1: CGPoint(x: 17.537566, y: 9), control2: CGPoint(x: 20, y: 11.462434))
            path.addCurve(to: CGPoint(x: 14.5, y: 20), control1: CGPoint(x: 20, y: 17.537566), control2: CGPoint(x: 17.537566, y: 20))
            path.addLine(to: CGPoint(x: 11, y: 20))
            result["undo-2"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 12, y: 3))
            path.addLine(to: CGPoint(x: 12, y: 15))
            path.move(to: CGPoint(x: 17, y: 8))
            path.addLine(to: CGPoint(x: 12, y: 3))
            path.addLine(to: CGPoint(x: 7, y: 8))
            path.move(to: CGPoint(x: 21, y: 15))
            path.addLine(to: CGPoint(x: 21, y: 19))
            path.addCurve(to: CGPoint(x: 19, y: 21), control1: CGPoint(x: 21, y: 20.104569), control2: CGPoint(x: 20.104569, y: 21))
            path.addLine(to: CGPoint(x: 5, y: 21))
            path.addCurve(to: CGPoint(x: 3, y: 19), control1: CGPoint(x: 3.895431, y: 21), control2: CGPoint(x: 3, y: 20.104569))
            path.addLine(to: CGPoint(x: 3, y: 15))
            result["upload"] = path.copy()!
        }
        do {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 18, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 18))
            path.move(to: CGPoint(x: 6, y: 6))
            path.addLine(to: CGPoint(x: 18, y: 18))
            result["x"] = path.copy()!
        }
        return result
    }
}
