import XCTest
@testable import AccountSDKIOSWeb

private struct TestData: Codable, Equatable {
    let key1: Float
    let key2: Bool
}

final class DefaultStorageTests: XCTestCase {
    private let userDefaults: UserDefaults! = UserDefaults(suiteName: #file)!

    override func setUp() {
        DefaultStorage.storage = UserDefaultsStorage(userDefaults)
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: #file)
    }

    func testSetValueEncodesValue() {
        let testData = TestData(key1: 1.0, key2: true)
        let key = "test key"
        
        XCTAssertTrue(DefaultStorage.setValue(testData, forKey: key))
        let stored = userDefaults.value(forKey: UserDefaultsStorage.addPrefix(toKey: key)) as! Data
        let deserialised = try? JSONDecoder().decode(TestData.self, from: stored)
        XCTAssertEqual(deserialised, testData)
    }
    
    func testSetValueReturnsFalseForValueFailingSerialisation() {
        // Float.infinity can't be JSON serialised by defult
        let testData = TestData(key1: Float.infinity, key2: true)
        
        XCTAssertFalse(DefaultStorage.setValue(testData, forKey: "test key"))
    }
    
    func testValueDecodesExistingValue() {
        let testData = TestData(key1: 1.0, key2: true)
        let key = "test key"
        
        let serialised = try? JSONEncoder().encode(testData)
        userDefaults.setValue(serialised, forKey: UserDefaultsStorage.addPrefix(toKey: key))
        
        let stored: TestData? = DefaultStorage.value(forKey: key)
        XCTAssertEqual(stored, testData)
    }
    
    func testValueReturnNilForMissingValue() {
        XCTAssertNil(DefaultStorage.value(forKey: "test key") as TestData?)
    }
    
    func testValueReturnNilForValueThatFailsDeserialisation() {
        let key = "test key"
        userDefaults.setValue("plain string", forKey: UserDefaultsStorage.addPrefix(toKey: key))
        XCTAssertNil(DefaultStorage.value(forKey: "test key") as TestData?)
    }
}