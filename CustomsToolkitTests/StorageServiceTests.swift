import XCTest
@testable import CustomsToolkit

final class StorageServiceTests: XCTestCase {
    
    private var testDefaults: UserDefaults!
    private var testSuiteName = "CustomsToolkitTestsSuite"
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults.removePersistentDomain(forName: testSuiteName)
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        super.tearDown()
    }
    
    func testAddRecentSearchesFIFOAndDeduplication() {
        let storage = StorageService(defaults: testDefaults)
        
        // Add searches
        storage.addRecentHSSearch(query: "3303")
        storage.addRecentHSSearch(query: "7113")
        storage.addRecentHSSearch(query: "3303 00 10")
        
        XCTAssertEqual(storage.recentHSSearches.count, 3)
        XCTAssertEqual(storage.recentHSSearches[0].normalizedQuery, "33030010")
        XCTAssertEqual(storage.recentHSSearches[1].normalizedQuery, "7113")
        XCTAssertEqual(storage.recentHSSearches[2].normalizedQuery, "3303")
        
        // Re-adding "3303" moves it to front and deduplicates
        storage.addRecentHSSearch(query: "33 03")
        XCTAssertEqual(storage.recentHSSearches.count, 3)
        XCTAssertEqual(storage.recentHSSearches[0].normalizedQuery, "3303")
    }
    
    func testMaxRecentSearchesLimit() {
        let storage = StorageService(defaults: testDefaults)
        
        for i in 1...15 {
            storage.addRecentHSSearch(query: "Code\(i)")
        }
        
        // Maximum 10 items preserved
        XCTAssertEqual(storage.recentHSSearches.count, 10)
    }
    
    func testClearRecentSearches() {
        let storage = StorageService(defaults: testDefaults)
        storage.addRecentHSSearch(query: "3303")
        XCTAssertFalse(storage.recentHSSearches.isEmpty)
        
        storage.clearRecentHSSearches()
        XCTAssertTrue(storage.recentHSSearches.isEmpty)
    }
}
