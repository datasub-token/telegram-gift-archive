import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

/// The owner's archive of profile gifts. An archived gift leaves every other tab of the gifts pane and is listed in
/// the Archive tab instead. The archive is kept on this device only, in UserDefaults per account and profile, and
/// nothing about it is sent to the server.
final class GiftsArchive {
    private static var archives: [String: GiftsArchive] = [:]
    
    /// One instance per account and profile, so the pane and every grid it shows observe the same state.
    static func archive(context: AccountContext, peerId: EnginePeer.Id) -> GiftsArchive {
        let defaultsKey = "PeerInfoGiftsArchive_v1_\(context.account.peerId.toInt64())_\(peerId.toInt64())"
        if let current = self.archives[defaultsKey] {
            return current
        }
        let archive = GiftsArchive(defaultsKey: defaultsKey)
        self.archives[defaultsKey] = archive
        return archive
    }
    
    static func itemKey(reference: StarGiftReference) -> String {
        switch reference {
        case let .message(messageId):
            return "m_\(messageId.peerId.toInt64())_\(messageId.namespace)_\(messageId.id)"
        case let .peer(peerId, id):
            return "p_\(peerId.toInt64())_\(id)"
        case let .slug(slug):
            return "s_\(slug)"
        }
    }
    
    private let defaultsKey: String
    private(set) var itemKeys: Set<String>
    private let itemKeysPromise: ValuePromise<Set<String>>
    
    var itemKeysSignal: Signal<Set<String>, NoError> {
        return self.itemKeysPromise.get()
    }
    
    private init(defaultsKey: String) {
        self.defaultsKey = defaultsKey
        
        let itemKeys = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
        self.itemKeys = itemKeys
        self.itemKeysPromise = ValuePromise(itemKeys, ignoreRepeated: true)
    }
    
    func contains(_ reference: StarGiftReference?) -> Bool {
        guard let reference else {
            return false
        }
        return self.itemKeys.contains(GiftsArchive.itemKey(reference: reference))
    }
    
    func setIsArchived(_ isArchived: Bool, reference: StarGiftReference) {
        let itemKey = GiftsArchive.itemKey(reference: reference)
        var itemKeys = self.itemKeys
        if isArchived {
            itemKeys.insert(itemKey)
        } else {
            itemKeys.remove(itemKey)
        }
        if itemKeys == self.itemKeys {
            return
        }
        self.itemKeys = itemKeys
        
        if itemKeys.isEmpty {
            UserDefaults.standard.removeObject(forKey: self.defaultsKey)
        } else {
            UserDefaults.standard.set(itemKeys.sorted(), forKey: self.defaultsKey)
        }
        self.itemKeysPromise.set(itemKeys)
    }
}
