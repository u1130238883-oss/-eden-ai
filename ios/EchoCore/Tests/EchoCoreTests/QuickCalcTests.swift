import XCTest
@testable import EchoCore

final class QuickCalcTests: XCTestCase {
    func a(_ q: String) -> String { QuickCalc.answer(q) ?? "<nil>" }

    func testYearsAndDates() {
        XCTAssertTrue(a("1995年出生屬什麼生肖？").contains("屬豬"))
        XCTAssertTrue(a("1984年是什麼年？").contains("甲子"))
        XCTAssertTrue(a("2025年3月20日再過5天是幾月幾日？").contains("3月25日"))
    }

    func testLogic() {
        XCTAssertTrue(a("一個人面向東，向後轉後面向哪裡？").hasSuffix("面向西。"))
        XCTAssertTrue(a("一個人面向南，向左轉後面向哪裡？").hasSuffix("面向東。"))
        XCTAssertTrue(a("面向北，先向右轉再向右轉，會面向哪個方向？").hasSuffix("面向南。"))
        XCTAssertTrue(a("鐘面上 6 點整，時針和分針的夾角是幾度？").contains("夾角是 180 度"))
        XCTAssertTrue(a("3點半時針和分針的夾角是幾度").contains("夾角是 75 度"))
        XCTAssertTrue(a("如果現在是下午 3 點，再過 10 個小時是幾點？").contains("隔天凌晨1點"))
        XCTAssertTrue(a("早上九點再過三個小時是幾點").contains("中午12點"))
        XCTAssertTrue(a("爸爸的爸爸叫什麼？").contains("爺爺"))
        XCTAssertTrue(a("媽媽的弟弟叫什麼").contains("舅舅"))
        XCTAssertTrue(a("哥哥的兒子叫我什麼（我是男生）？").contains("叔叔"))
        XCTAssertTrue(a("一根繩子對折再對折，剪一刀，變成幾段？").contains("＝5 段"))
        XCTAssertEqual(QuickCalc.answer("你今天過得怎麼樣？"), nil)
    }

    func testChinese() {
        XCTAssertTrue(a("「再接再ㄌㄧˋ」的ㄌㄧˋ是哪個字？").contains("是「厲」"))
        XCTAssertTrue(a("「一ㄈㄢ風順」的ㄈㄢ是哪個字？").contains("是「帆」"))
        XCTAssertTrue(a("「迫不及ㄉㄞˋ」的ㄉㄞˋ是哪個字？").contains("是「待」"))
        XCTAssertTrue(a("「長」在「校長」裡念什麼？").contains("ㄓㄤˇ"))
        XCTAssertTrue(a("「樂」在「音樂」裡念什麼？").contains("ㄩㄝˋ"))
        XCTAssertTrue(a("「行」在「銀行」裡念什麼？").contains("ㄏㄤˊ"))
        XCTAssertTrue(a("「慢慢地」的「地」怎麼念？").contains("˙ㄉㄜ"))
    }

    func testRound14Misses() {
        XCTAssertTrue(a("如果今天是星期一，三天前是星期幾？").contains("3 天前是星期五"))
        XCTAssertTrue(a("今天星期六，再過10天是星期幾").contains("是星期二"))
        XCTAssertTrue(a("第 26 號元素是什麼？").contains("鐵"))
        XCTAssertTrue(a("第36號元素是什麼").contains("氪"))
        XCTAssertTrue(a("雞和兔關在一起，共有19個頭、54隻腳，雞和兔各幾隻？").hasPrefix("雞 11 隻、兔 8 隻"))
        XCTAssertTrue(a("三個人三天吃三個蘋果，九個人九天吃幾個蘋果？").hasPrefix("27 個蘋果"))
        XCTAssertTrue(a("5台機器5分鐘做5個零件，100台機器100分鐘做幾個零件").hasPrefix("2000 個零件"))
    }

    func testGenderAsideIsNotProfile() {
        XCTAssertNil(ProfileParser.parse("哥哥的兒子叫我什麼（我是男生）？"))
        XCTAssertEqual(ProfileParser.parse("我是男生")?.male, true)
        XCTAssertEqual(ProfileParser.parse("我是女生，幫我排八字")?.male, false)
    }
}
