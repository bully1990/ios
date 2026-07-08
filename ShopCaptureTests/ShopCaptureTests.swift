import XCTest
@testable import ShopCapture

final class ShopCaptureTests: XCTestCase {
    func testExtractsChineseMobileNumber() {
        let text = "欢迎光临\n联系电话 138 0013 8000"
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "13800138000")
    }

    func testExtractsShopSignMobileNumberWithGroupedDigits() {
        let text = "大展新旧货\n电话：172 6668 8538"
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "17266688538")
    }

    func testExtractsMultiplePhoneNumbers() {
        let text = "非凡通讯\n电话:17633944176 17633555849"
        XCTAssertEqual(PhoneNumberExtractor.allPhoneNumbers(in: text), ["17633944176", "17633555849"])
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "17633944176")
    }

    func testExtractsMobileNumberWithCommonOCRDigitMistakes() {
        let text = "电话：17Z 666B B538"
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "17266688538")
    }

    func testExtractsLandlineNumber() {
        let text = "订餐电话：010-88886666"
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "01088886666")
    }

    func testExtractsValidLandlineWithoutPhoneKeyword() {
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: "0755-88886666"), "075588886666")
    }

    func testRejectsTextWithoutPhoneNumber() {
        XCTAssertNil(PhoneNumberExtractor.firstPhoneNumber(in: "营业时间 09:00-18:00"))
    }

    func testRejectsComputerScreenNumberWithoutValidPhonePrefix() {
        let text = """
        您是对重疾险有什么偏见吗
        038008490848
        未整理出服务内容
        """

        XCTAssertNil(PhoneNumberExtractor.firstPhoneNumber(in: text))
    }

    func testLocalSummaryExtractsTrailingShopNameAndServices() {
        let text = """
        钣金剪折弯 激光切割加工
        羽硕一铁板 冷轧板 4米哥折堂 创槽
        经种机箱一桃柜订做三焊接加工
        电话：138 2610 8311
        大月
        """

        let summary = ShopTextSummarizer.summarizeLocally(fullText: text, phoneNumber: "13826108311")
        XCTAssertEqual(summary?.shopName, "大月")
        XCTAssertEqual(summary?.serviceContent, "钣金剪折弯 激光切割加工；羽硕 铁板 冷轧板 4米哥折堂 创槽；经种机箱 桃柜订做三焊接加工")
    }

    func testLocalSummaryBuildsNameFromServicesWhenNameMissing() {
        let text = """
        钣金剪折弯 激光切割加工
        铁板 冷轧板 机箱订做 焊接加工
        电话：138 2610 8311
        """

        let summary = ShopTextSummarizer.summarizeLocally(fullText: text, phoneNumber: "13826108311")
        XCTAssertEqual(summary?.shopName, "钣金切割加工")
        XCTAssertEqual(summary?.serviceContent, "钣金剪折弯 激光切割加工；铁板 冷轧板 机箱订做 焊接加工")
    }

    func testSummaryPreservesServiceSpacingAsSeparators() {
        let summary = ShopTextSummary(shopName: "手机专业维修", serviceContent: "新机 二手 配件 批发 回收")
        let refined = ShopTextSummarizer.refine(summary, fullText: nil)
        XCTAssertEqual(refined?.serviceContent, "新机、二手、配件、批发、回收")
    }

    func testSummarySplitsJoinedServiceWords() {
        let summary = ShopTextSummary(shopName: "手机专业维修", serviceContent: "新机二手配件批发回收")
        let refined = ShopTextSummarizer.refine(summary, fullText: nil)
        XCTAssertEqual(refined?.serviceContent, "新机、二手、配件、批发、回收")
    }

    func testOCRContextPrioritizesTextWithSameBackgroundAsPhoneLine() {
        let signColor = OCRBackgroundColor(red: 0.9, green: 0.7, blue: 0.2)
        let neighborColor = OCRBackgroundColor(red: 0.2, green: 0.7, blue: 0.9)
        let lines = [
            OCRTextLine(text: "隔壁店", boundingBox: CGRect(x: 0.05, y: 0.7, width: 0.2, height: 0.1), backgroundColor: neighborColor),
            OCRTextLine(text: "主招牌", boundingBox: CGRect(x: 0.42, y: 0.68, width: 0.25, height: 0.1), backgroundColor: signColor),
            OCRTextLine(text: "特色小炒 外卖", boundingBox: CGRect(x: 0.4, y: 0.52, width: 0.35, height: 0.08), backgroundColor: signColor),
            OCRTextLine(text: "电话:13800138000", boundingBox: CGRect(x: 0.42, y: 0.38, width: 0.35, height: 0.08), backgroundColor: signColor)
        ]

        let text = OCRTextContextBuilder.prioritizedText(from: lines, phoneNumber: "13800138000")

        XCTAssertTrue(text.contains("同背景候选区域"))
        XCTAssertTrue(text.contains("主招牌\n特色小炒 外卖\n电话:13800138000"))
        XCTAssertFalse(text.components(separatedBy: "全部OCR文本").first?.contains("隔壁店") ?? true)
    }

    func testLocalSummaryPrefersSameBackgroundSectionWhenPresent() {
        let text = """
        同背景候选区域（优先参考，与电话行背景颜色接近）:
        主招牌
        特色小炒 外卖
        电话:13800138000

        全部OCR文本:
        隔壁店
        主招牌
        特色小炒 外卖
        电话:13800138000
        """

        let summary = ShopTextSummarizer.summarizeLocally(fullText: text, phoneNumber: "13800138000")
        XCTAssertEqual(summary?.shopName, "主招牌")
    }

}
