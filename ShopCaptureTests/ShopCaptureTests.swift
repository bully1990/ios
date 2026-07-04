import XCTest
@testable import ShopCapture

final class ShopCaptureTests: XCTestCase {
    func testExtractsChineseMobileNumber() {
        let text = "欢迎光临\n联系电话 138 0013 8000"
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "13800138000")
    }

    func testExtractsLandlineNumber() {
        let text = "订餐电话：010-88886666"
        XCTAssertEqual(PhoneNumberExtractor.firstPhoneNumber(in: text), "01088886666")
    }

    func testRejectsTextWithoutPhoneNumber() {
        XCTAssertNil(PhoneNumberExtractor.firstPhoneNumber(in: "营业时间 09:00-18:00"))
    }
}
