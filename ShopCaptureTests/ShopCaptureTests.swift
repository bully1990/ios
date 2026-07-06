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

    func testExtractsMobileNumberWithCommonOCRDigitMistakes() {
        let text = "电话：17Z 666B B538"
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "17266688538")
    }

    func testExtractsLandlineNumber() {
        let text = "订餐电话：010-88886666"
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "01088886666")
    }

    func testRejectsTextWithoutPhoneNumber() {
        XCTAssertNil(PhoneNumberExtractor.firstPhoneNumber(in: "营业时间 09:00-18:00"))
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

    func testSummaryCorrectsNeighborSignNameForWoodenBucketRice() {
        let summary = ShopTextSummary(
            shopName: "辛草",
            serviceContent: "棋牌、特色小炒、本桶饭、正宗湘菜、小锅爆炒、外卖"
        )

        let refined = ShopTextSummarizer.refine(summary, fullText: "外卖电话:18566583508\n木桶饭")
        XCTAssertEqual(refined?.shopName, "木桶饭")
        XCTAssertEqual(refined?.serviceContent, "棋牌、特色小炒、木桶饭、正宗湘菜、小锅爆炒、外卖")
    }
}
