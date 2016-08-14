//
//  MemoryStorage.swift
//  DTModelStorageTests
//
//  Created by Denys Telezhkin on 10.07.15.
//  Copyright (c) 2015 Denys Telezhkin. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/// This struct contains error types that can be thrown for various MemoryStorage errors
public struct MemoryStorageErrors
{
    /// Errors that can happen when inserting items into memory storage - `insertItem(_:toIndexPath:)` method
    public enum Insertion: Error
    {
        case indexPathTooBig
    }
    
    /// Errors that can be thrown, when calling `insertItems(_:toIndexPaths:)` method
    public enum BatchInsertion: Error
    {
        /// Is thrown, if length of batch inserted array is different from length of array of index paths.
        case itemsCountMismatch
    }
    
    /// Errors that can happen when replacing item in memory storage - `replaceItem(_:replacingItem:)` method
    public enum Replacement: Error
    {
        case itemNotFound
    }
    
    /// Errors that can happen when removing item from memory storage - `removeItem(:_)` method
    public enum Removal : Error
    {
        case itemNotFound
    }
}

/// This class represents model storage in memory.
///
/// `MemoryStorage` stores data models like array of `SectionModel` instances. It has various methods for changing storage contents - add, remove, insert, replace e.t.c.
/// - Note: It also notifies it's delegate about underlying changes so that delegate can update interface accordingly
/// - SeeAlso: `SectionModel`
public class MemoryStorage: BaseStorage, StorageProtocol, SupplementaryStorageProtocol, SectionLocationIdentifyable
{
    /// sections of MemoryStorage
    public var sections: [Section] = [SectionModel]() {
        didSet {
            sections.forEach {
                ($0 as? SectionModel)?.sectionLocationDelegate = self
            }
        }
    }
    
    public func sectionIndex(for section: Section) -> Int? {
        return sections.index(where: {
            return ($0 as? SectionModel) === (section as? SectionModel)
        })
    }
    
    /// Returns total number of items contained in all `MemoryStorage` sections
    public var totalNumberOfItems : Int {
        return sections.reduce(0) { sum, section in
            return sum + section.numberOfItems
        }
    }
    
    /// Retrieve item at index path from `MemoryStorage`
    /// - Parameter path: NSIndexPath for item
    /// - Returns: model at indexPath or nil, if item not found
    public func itemAtIndexPath(_ path: IndexPath) -> Any? {
        let sectionModel : SectionModel
        if path.section >= self.sections.count {
            return nil
        }
        else {
            sectionModel = self.sections[path.section] as! SectionModel
            if path.item >= sectionModel.numberOfItems {
                return nil
            }
        }
        return sectionModel.items[path.item]
    }
    
    /// Set section header model for MemoryStorage
    /// - Note: This does not update UI
    /// - Parameter model: model for section header at index
    /// - Parameter sectionIndex: index of section for setting header
    public func setSectionHeaderModel<T>(_ model: T?, forSectionIndex sectionIndex: Int)
    {
        assert(self.supplementaryHeaderKind != nil, "supplementaryHeaderKind property was not set before calling setSectionHeaderModel: forSectionIndex: method")
        let section = getValidSection(sectionIndex)
        section.setSupplementaryModel(model, forKind: self.supplementaryHeaderKind!, atIndex: 0)
        delegate?.storageNeedsReloading()
    }
    
    /// Set section footer model for MemoryStorage
    /// - Note: This does not update UI
    /// - Parameter model: model for section footer at index
    /// - Parameter sectionIndex: index of section for setting footer
    public func setSectionFooterModel<T>(_ model: T?, forSectionIndex sectionIndex: Int)
    {
        assert(self.supplementaryFooterKind != nil, "supplementaryFooterKind property was not set before calling setSectionFooterModel: forSectionIndex: method")
        let section = getValidSection(sectionIndex)
        section.setSupplementaryModel(model, forKind: self.supplementaryFooterKind!, atIndex: 0)
        delegate?.storageNeedsReloading()
    }
    
    /// Set supplementaries for specific kind. Usually it's header or footer kinds.
    /// - Parameter models: supplementary models for sections
    /// - Parameter kind: supplementary kind
    public func setSupplementaries(_ models : [[Int: Any]], forKind kind: String)
    {
        defer {
            self.delegate?.storageNeedsReloading()
        }
        
        if models.count == 0 {
            for index in 0..<self.sections.count {
                let section = self.sections[index] as? SupplementaryAccessible
                section?.supplementaries[kind] = nil
            }
            return
        }
        
        _ = getValidSection(models.count - 1)
        
        for index in 0 ..< models.count {
            let section = self.sections[index] as? SupplementaryAccessible
            section?.supplementaries[kind] = models[index]
        }
    }
    
    /// Set section header models.
    /// - Note: `supplementaryHeaderKind` property should be set before calling this method.
    /// - Parameter models: section header models
    public func setSectionHeaderModels<T>(_ models : [T])
    {
        assert(self.supplementaryHeaderKind != nil, "Please set supplementaryHeaderKind property before setting section header models")
        var supplementaries = [[Int:Any]]()
        for model in models {
            supplementaries.append([0:model])
        }
        self.setSupplementaries(supplementaries, forKind: self.supplementaryHeaderKind!)
    }
    
    /// Set section footer models.
    /// - Note: `supplementaryFooterKind` property should be set before calling this method.
    /// - Parameter models: section footer models
    public func setSectionFooterModels<T>(_ models : [T])
    {
        assert(self.supplementaryFooterKind != nil, "Please set supplementaryFooterKind property before setting section header models")
        var supplementaries = [[Int:Any]]()
        for model in models {
            supplementaries.append([0:model])
        }
        self.setSupplementaries(supplementaries, forKind: self.supplementaryFooterKind!)
    }
    
    /// Set items for specific section. This will reload UI after updating.
    /// - Parameter items: items to set for section
    /// - Parameter forSectionIndex: index of section to update
    public func setItems<T>(_ items: [T], forSectionIndex index: Int = 0)
    {
        let section = self.getValidSection(index)
        section.items.removeAll(keepingCapacity: false)
        for item in items { section.items.append(item) }
        self.delegate?.storageNeedsReloading()
    }
    
    /// Set section for specific index. This will reload UI after updating
    /// - Parameter section: section to set for specific index
    /// - Parameter forSectionIndex: index of section
    public func setSection(_ section: SectionModel, forSectionIndex index: Int)
    {
        let _ = self.getValidSection(index)
        sections.replaceSubrange(index...index, with: [section as Section])
        delegate?.storageNeedsReloading()
    }
    
    /// Insert section. This method is assumed to be used, when you need to insert section with items and supplementaries in one batch operation. If you need to simply add items, use `addItems` or `setItems` instead.
    /// - Parameter section: section to insert
    /// - Parameter atIndex: index of section to insert. If `atIndex` is larger than number of sections, method does nothing.
    public func insertSection(_ section: SectionModel, atIndex sectionIndex: Int) {
        guard sectionIndex <= sections.count else { return }
        startUpdate()
        sections.insert(section, at: sectionIndex)
        currentUpdate?.insertedSectionIndexes.insert(sectionIndex)
        for item in 0..<section.numberOfItems {
            currentUpdate?.insertedRowIndexPaths.insert(IndexPath(item: item, section: sectionIndex))
        }
        finishUpdate()
    }
    
    /// Add items to section with `toSection` number.
    /// - Parameter items: items to add
    /// - Parameter toSection: index of section to add items
    public func addItems<T>(_ items: [T], toSection index: Int = 0)
    {
        self.startUpdate()
        let section = self.getValidSection(index)
        
        for item in items {
            let numberOfItems = section.numberOfItems
            section.items.append(item)
            self.currentUpdate?.insertedRowIndexPaths.insert(IndexPath(item: numberOfItems, section: index))
        }
        self.finishUpdate()
    }
    
    /// Add item to section with `toSection` number.
    /// - Parameter item: item to add
    /// - Parameter toSection: index of section to add item
    public func addItem<T>(_ item: T, toSection index: Int = 0)
    {
        self.startUpdate()
        let section = self.getValidSection(index)
        let numberOfItems = section.numberOfItems
        section.items.append(item)
        self.currentUpdate?.insertedRowIndexPaths.insert(IndexPath(item: numberOfItems, section: index))
        self.finishUpdate()
    }
    
    /// Insert item to indexPath
    /// - Parameter item: item to insert
    /// - Parameter toIndexPath: indexPath to insert
    /// - Throws: if indexPath is too big, will throw MemoryStorageErrors.Insertion.IndexPathTooBig
    public func insertItem<T>(_ item: T, toIndexPath indexPath: IndexPath) throws
    {
        self.startUpdate()
        let section = self.getValidSection((indexPath as NSIndexPath).section)
        
        guard section.items.count >= indexPath.item else { throw MemoryStorageErrors.Insertion.indexPathTooBig }
        
        section.items.insert(item, at: indexPath.item)
        self.currentUpdate?.insertedRowIndexPaths.insert(indexPath)
        self.finishUpdate()
    }
    
    /// Insert item to indexPaths
    /// - Parameter items: items to insert
    /// - Parameter toIndexPaths: indexPaths to insert
    /// - Throws: if items.count is different from indexPaths.count, will throw MemoryStorageErrors.BatchInsertion.ItemsCountMismatch
    public func insertItems<T>(_ items: [T], toIndexPaths indexPaths: [IndexPath]) throws
    {
        if items.count != indexPaths.count {
            throw MemoryStorageErrors.BatchInsertion.itemsCountMismatch
        }
        performUpdates {
            indexPaths.enumerated().forEach { itemIndex, indexPath in
                let section = getValidSection(indexPath.section)
                guard section.items.count >= indexPath.item else {
                    return
                }
                section.items.insert(items[itemIndex], at: indexPath.item)
                currentUpdate?.insertedRowIndexPaths.insert(indexPath)
            }
        }
    }
    
    /// Reload item
    /// - Parameter item: item to reload.
    public func reloadItem<T:Equatable>(_ item: T)
    {
        self.startUpdate()
        if let indexPath = self.indexPathForItem(item) {
            self.currentUpdate?.updatedRowIndexPaths.insert(indexPath)
        }
        self.finishUpdate()
    }
    
    /// Replace item `itemToReplace` with `replacingItem`.
    /// - Parameter itemToReplace: item to replace
    /// - Parameter replacingItem: replacing item
    /// - Throws: if `itemToReplace` is not found, will throw MemoryStorageErrors.Replacement.ItemNotFound
    public func replaceItem<T: Equatable>(_ itemToReplace: T, replacingItem: Any) throws
    {
        self.startUpdate()
        defer { self.finishUpdate() }
        
        guard let originalIndexPath = self.indexPathForItem(itemToReplace) else {
            throw MemoryStorageErrors.Replacement.itemNotFound
        }
        
        let section = self.getValidSection(originalIndexPath.section)
        section.items[originalIndexPath.item] = replacingItem
        
        self.currentUpdate?.updatedRowIndexPaths.insert(originalIndexPath)
    }
    
    /// Remove item `item`.
    /// - Parameter item: item to remove
    /// - Throws: if item is not found, will throw MemoryStorageErrors.Removal.ItemNotFound
    public func removeItem<T:Equatable>(_ item: T) throws
    {
        self.startUpdate()
        defer { self.finishUpdate() }
        
        guard let indexPath = self.indexPathForItem(item) else {
            throw MemoryStorageErrors.Removal.itemNotFound
        }
        self.getValidSection(indexPath.section).items.remove(at: indexPath.item)
        
        self.currentUpdate?.deletedRowIndexPaths.insert(indexPath)
    }
    
    /// Remove items
    /// - Parameter items: items to remove
    /// - Note: Any items that were not found, will be skipped
    public func removeItems<T:Equatable>(_ items: [T])
    {
        self.startUpdate()
        
        let indexPaths = indexPathArrayForItems(items)
        for indexPath in self.dynamicType.sortedArrayOfIndexPaths(indexPaths, ascending: false)
        {
            self.getValidSection(indexPath.section).items.remove(at: indexPath.item)
            self.currentUpdate?.deletedRowIndexPaths.insert(indexPath)
        }
        self.finishUpdate()
    }
    
    /// Remove items at index paths.
    /// - Parameter indexPaths: indexPaths to remove item from. Any indexPaths that will not be found, will be skipped
    public func removeItemsAtIndexPaths(_ indexPaths : [IndexPath])
    {
        self.startUpdate()
        
        let reverseSortedIndexPaths = self.dynamicType.sortedArrayOfIndexPaths(indexPaths, ascending: false)
        for indexPath in reverseSortedIndexPaths
        {
            if let _ = self.itemAtIndexPath(indexPath)
            {
                self.getValidSection(indexPath.section).items.remove(at: indexPath.item)
                self.currentUpdate?.deletedRowIndexPaths.insert(indexPath)
            }
        }
        
        self.finishUpdate()
    }
    
    /// Delete sections in indexSet
    /// - Parameter sections: sections to delete
    public func deleteSections(_ sections : IndexSet)
    {
        self.startUpdate()
        
        var i = sections.last
        while i != NSNotFound && i < self.sections.count {
            self.sections.remove(at: i!)
            self.currentUpdate?.deletedSectionIndexes.insert(i!)
            i = sections.integerLessThan(i!)
        }
        
        self.finishUpdate()
    }
    
    /// Move section from `sourceSectionIndex` to `destinationSectionIndex`.
    /// - Parameter sourceSectionIndex: index of section, from which we'll be moving
    /// - Parameter destinationSectionIndex: index of section, where we'll be moving
    public func moveSection(_ sourceSectionIndex: Int, toSection destinationSectionIndex: Int) {
        self.startUpdate()
        let validSectionFrom = getValidSection(sourceSectionIndex)
        let _ = getValidSection(destinationSectionIndex)
        sections.remove(at: sourceSectionIndex)
        sections.insert(validSectionFrom, at: destinationSectionIndex)
        currentUpdate?.movedSectionIndexes.append([sourceSectionIndex,destinationSectionIndex])
        self.finishUpdate()
    }
    
    /// Move item from `source` indexPath to `destination` indexPath.
    /// - Parameter source: indexPath from which we need to move
    /// - Parameter toIndexPath: destination index path for item
    public func moveItemAtIndexPath(_ source: IndexPath, toIndexPath destination: IndexPath)
    {
        self.startUpdate()
        defer { self.finishUpdate() }
        
        guard let sourceItem = itemAtIndexPath(source) else {
            print("MemoryStorage: source indexPath should not be nil when moving item")
            return
        }
        let sourceSection = getValidSection(source.section)
        let destinationSection = getValidSection(destination.section)
        
        if destinationSection.items.count < destination.row {
            print("MemoryStorage: failed moving item to indexPath: \(destination), only \(destinationSection.items.count) items in section")
            return
        }
        sourceSection.items.remove(at: source.row)
        destinationSection.items.insert(sourceItem, at: destination.item)
        currentUpdate?.movedRowIndexPaths.append([source,destination])
    }
    
    /// Remove all items.
    /// - Note: method will call .reloadData() when it finishes.
    public func removeAllItems()
    {
        for section in self.sections {
            (section as? SectionModel)?.items.removeAll(keepingCapacity: false)
        }
        delegate?.storageNeedsReloading()
    }
    
    /// Remove all items from specific section
    /// - parameter atIndex: index of section
    public func removeItemsFromSection(atIndex: Int) {
        startUpdate()
        defer { finishUpdate() }
        
        guard let section = sectionAtIndex(atIndex) else { return }
        
        for (index,_) in section.items.enumerated(){
            currentUpdate?.deletedRowIndexPaths.insert(IndexPath(item: index, section: atIndex))
        }
        section.items.removeAll()
    }
    
    // MARK: - Searching in storage
    
    /// Retrieve items in section
    /// - Parameter section: index of section
    /// - Returns array of items in section or nil, if section does not exist
    public func itemsInSection(_ section: Int) -> [Any]?
    {
        if self.sections.count > section {
            return self.sections[section].items
        }
        return nil
    }
    
    /// Find index path of specific item in MemoryStorage
    /// - Parameter searchableItem: item to find
    /// - Returns: index path for found item, nil if not found
    public func indexPathForItem<T: Equatable>(_ searchableItem : T) -> IndexPath?
    {
        for sectionIndex in 0..<self.sections.count
        {
            let rows = self.sections[sectionIndex].items
            
            for rowIndex in 0..<rows.count {
                if let item = rows[rowIndex] as? T {
                    if item == searchableItem {
                        return IndexPath(item: rowIndex, section: sectionIndex)
                    }
                }
            }
            
        }
        return nil
    }
    
    /// Retrieve section model for specific section.
    /// - Parameter sectionIndex: index of section
    /// - Note: if section did not exist prior to calling this, it will be created, and UI updated.
    public func sectionAtIndex(_ sectionIndex : Int) -> SectionModel?
    {
        if sections.count > sectionIndex {
            return sections[sectionIndex] as? SectionModel
        }
        return nil
    }
    
    /// Find-or-create section
    /// - Parameter sectionIndex: indexOfSection
    /// - Note: This method finds or create a SectionModel. It means that if you create section 2, section 0 and 1 will be automatically created.
    /// - Returns: SectionModel
    func getValidSection(_ sectionIndex : Int) -> SectionModel
    {
        if sectionIndex < self.sections.count
        {
            return self.sections[sectionIndex] as! SectionModel
        }
        else {
            for i in self.sections.count...sectionIndex {
                self.sections.append(SectionModel())
                self.currentUpdate?.insertedSectionIndexes.insert(i)
            }
        }
        return self.sections.last as! SectionModel
    }
    
    /// Index path array for items
    /// - Parameter items: items to find in storage
    /// - Returns: Array if NSIndexPaths for found items
    func indexPathArrayForItems<T:Equatable>(_ items:[T]) -> [IndexPath]
    {
        var indexPaths = [IndexPath]()
        
        for index in 0..<items.count {
            if let indexPath = self.indexPathForItem(items[index])
            {
                indexPaths.append(indexPath)
            }
        }
        return indexPaths
    }
    
    /// Sorted array of index paths - useful for deletion.
    /// - Parameter indexPaths: Array of index paths to sort
    /// - Parameter ascending: sort in ascending or descending order
    /// - Note: This method is used, when you need to delete multiple index paths. Sorting them in reverse order preserves initial collection from mutation while enumerating
    class func sortedArrayOfIndexPaths(_ indexPaths: [IndexPath], ascending: Bool) -> [IndexPath]
    {
        let unsorted = NSMutableArray(array: indexPaths)
        let descriptor = NSSortDescriptor(key: "self", ascending: ascending)
        return unsorted.sortedArray(using: [descriptor]) as? [IndexPath] ?? []
    }
    
    // MARK: - SupplementaryStorageProtocol
    
    /// Retrieve supplementary model of specific kind for section.
    /// - Parameter kind: kind of supplementary model
    /// - Parameter sectionIndex: index of section
    /// - SeeAlso: `headerModelForSectionIndex`
    /// - SeeAlso: `footerModelForSectionIndex`
    public func supplementaryModelOfKind(_ kind: String, sectionIndexPath: IndexPath) -> Any? {
        guard sectionIndexPath.section < sections.count else {
            return nil
        }
        return (self.sections[sectionIndexPath.section] as? SupplementaryAccessible)?.supplementaryModelOfKind(kind, atIndex: sectionIndexPath.item)
    }
}
