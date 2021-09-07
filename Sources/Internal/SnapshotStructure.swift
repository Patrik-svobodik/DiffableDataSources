import Foundation
import DifferenceKit

public struct SnapshotStructure<SectionID: Hashable, ItemID: Hashable> {
    public struct Item: Differentiable, Equatable {
        public var differenceIdentifier: ItemID
        public var isReloaded: Bool

        public init(id: ItemID, isReloaded: Bool) {
            self.differenceIdentifier = id
            self.isReloaded = isReloaded
        }

        public init(id: ItemID) {
            self.init(id: id, isReloaded: false)
        }

        public func isContentEqual(to source: Item) -> Bool {
            return !isReloaded && differenceIdentifier == source.differenceIdentifier
        }
    }

    public struct Section: DifferentiableSection, Equatable {
        public var differenceIdentifier: SectionID
        public var elements: [Item] = []
        public var isReloaded: Bool

        public init(id: SectionID, items: [Item], isReloaded: Bool) {
            self.differenceIdentifier = id
            self.elements = items
            self.isReloaded = isReloaded
        }

        public init(id: SectionID) {
            self.init(id: id, items: [], isReloaded: false)
        }

        public init<C: Swift.Collection>(source: Section, elements: C) where C.Element == Item {
            self.init(id: source.differenceIdentifier, items: Array(elements), isReloaded: source.isReloaded)
        }

        public func isContentEqual(to source: Section) -> Bool {
            return !isReloaded && differenceIdentifier == source.differenceIdentifier
        }
    }

    public var sections: [Section] = []

    public var allSectionIDs: [SectionID] {
        return sections.map { $0.differenceIdentifier }
    }

    public var allItemIDs: [ItemID] {
        return sections.lazy
            .flatMap { $0.elements }
            .map { $0.differenceIdentifier }
    }

    public func items(in sectionID: SectionID, file: StaticString = #file, line: UInt = #line) -> [ItemID] {
        guard let sectionIndex = sectionIndex(of: sectionID) else {
            specifiedSectionIsNotFound(sectionID, file: file, line: line)
        }

        return sections[sectionIndex].elements.map { $0.differenceIdentifier }
    }

    public func section(containing itemID: ItemID) -> SectionID? {
        return itemPositionMap()[itemID]?.section.differenceIdentifier
    }

    public mutating func append(itemIDs: [ItemID], to sectionID: SectionID? = nil, file: StaticString = #file, line: UInt = #line) {
        let index: Array<Section>.Index

        if let sectionID = sectionID {
            guard let sectionIndex = sectionIndex(of: sectionID) else {
                specifiedSectionIsNotFound(sectionID, file: file, line: line)
            }

            index = sectionIndex
        }
        else {
            guard !sections.isEmpty else {
                thereAreCurrentlyNoSections(file: file, line: line)
            }

            index = sections.index(before: sections.endIndex)
        }

        let items = itemIDs.lazy.map(Item.init)
        sections[index].elements.append(contentsOf: items)
    }

    public mutating func insert(itemIDs: [ItemID], before beforeItemID: ItemID, file: StaticString = #file, line: UInt = #line) {
        guard let itemPosition = itemPositionMap()[beforeItemID] else {
            specifiedItemIsNotFound(beforeItemID, file: file, line: line)
        }

        let items = itemIDs.lazy.map(Item.init)
        sections[itemPosition.sectionIndex].elements.insert(contentsOf: items, at: itemPosition.itemRelativeIndex)
    }

    public mutating func insert(itemIDs: [ItemID], after afterItemID: ItemID, file: StaticString = #file, line: UInt = #line) {
        guard let itemPosition = itemPositionMap()[afterItemID] else {
            specifiedItemIsNotFound(afterItemID, file: file, line: line)
        }

        let itemIndex = sections[itemPosition.sectionIndex].elements.index(after: itemPosition.itemRelativeIndex)
        let items = itemIDs.lazy.map(Item.init)
        sections[itemPosition.sectionIndex].elements.insert(contentsOf: items, at: itemIndex)
    }

    public mutating func remove(itemIDs: [ItemID]) {
        let itemPositionMap = self.itemPositionMap()
        var removeIndexSetMap = [Int: IndexSet]()

        for itemID in itemIDs {
            guard let itemPosition = itemPositionMap[itemID] else {
                continue
            }

            removeIndexSetMap[itemPosition.sectionIndex, default: []].insert(itemPosition.itemRelativeIndex)
        }

        for (sectionIndex, removeIndexSet) in removeIndexSetMap {
            for range in removeIndexSet.rangeView.reversed() {
                sections[sectionIndex].elements.removeSubrange(range)
            }
        }
    }

    public mutating func removeAllItems() {
        for sectionIndex in sections.indices {
            sections[sectionIndex].elements.removeAll()
        }
    }

    public mutating func move(itemID: ItemID, before beforeItemID: ItemID, file: StaticString = #file, line: UInt = #line) {
        guard let removed = remove(itemID: itemID) else {
            specifiedItemIsNotFound(itemID, file: file, line: line)
        }

        guard let itemPosition = itemPositionMap()[beforeItemID] else {
            specifiedItemIsNotFound(beforeItemID, file: file, line: line)
        }

        sections[itemPosition.sectionIndex].elements.insert(removed, at: itemPosition.itemRelativeIndex)
    }

    public mutating func move(itemID: ItemID, after afterItemID: ItemID, file: StaticString = #file, line: UInt = #line) {
        guard let removed = remove(itemID: itemID) else {
            specifiedItemIsNotFound(itemID, file: file, line: line)
        }

        guard let itemPosition = itemPositionMap()[afterItemID] else {
            specifiedItemIsNotFound(afterItemID, file: file, line: line)
        }

        let itemIndex = sections[itemPosition.sectionIndex].elements.index(after: itemPosition.itemRelativeIndex)
        sections[itemPosition.sectionIndex].elements.insert(removed, at: itemIndex)
    }

    public mutating func update(itemIDs: [ItemID], file: StaticString = #file, line: UInt = #line) {
        let itemPositionMap = self.itemPositionMap()

        for itemID in itemIDs {
            guard let itemPosition = itemPositionMap[itemID] else {
                specifiedItemIsNotFound(itemID, file: file, line: line)
            }

            sections[itemPosition.sectionIndex].elements[itemPosition.itemRelativeIndex].isReloaded = true
        }
    }

    public mutating func append(sectionIDs: [SectionID]) {
        let newSections = sectionIDs.lazy.map(Section.init)
        sections.append(contentsOf: newSections)
    }

    public mutating func insert(sectionIDs: [SectionID], before beforeSectionID: SectionID, file: StaticString = #file, line: UInt = #line) {
        guard let sectionIndex = sectionIndex(of: beforeSectionID) else {
            specifiedSectionIsNotFound(beforeSectionID, file: file, line: line)
        }

        let newSections = sectionIDs.lazy.map(Section.init)
        sections.insert(contentsOf: newSections, at: sectionIndex)
    }

    public mutating func insert(sectionIDs: [SectionID], after afterSectionID: SectionID, file: StaticString = #file, line: UInt = #line) {
        guard let beforeIndex = sectionIndex(of: afterSectionID) else {
            specifiedSectionIsNotFound(afterSectionID, file: file, line: line)
        }

        let sectionIndex = sections.index(after: beforeIndex)
        let newSections = sectionIDs.lazy.map(Section.init)
        sections.insert(contentsOf: newSections, at: sectionIndex)
    }

    public mutating func remove(sectionIDs: [SectionID]) {
        for sectionID in sectionIDs {
            remove(sectionID: sectionID)
        }
    }

    public mutating func move(sectionID: SectionID, before beforeSectionID: SectionID, file: StaticString = #file, line: UInt = #line) {
        guard let removed = remove(sectionID: sectionID) else {
            specifiedSectionIsNotFound(sectionID, file: file, line: line)
        }

        guard let sectionIndex = sectionIndex(of: beforeSectionID) else {
            specifiedSectionIsNotFound(beforeSectionID, file: file, line: line)
        }

        sections.insert(removed, at: sectionIndex)
    }

    public mutating func move(sectionID: SectionID, after afterSectionID: SectionID, file: StaticString = #file, line: UInt = #line) {
        guard let removed = remove(sectionID: sectionID) else {
            specifiedSectionIsNotFound(sectionID, file: file, line: line)
        }

        guard let beforeIndex = sectionIndex(of: afterSectionID) else {
            specifiedSectionIsNotFound(afterSectionID, file: file, line: line)
        }

        let sectionIndex = sections.index(after: beforeIndex)
        sections.insert(removed, at: sectionIndex)
    }

    public mutating func update(sectionIDs: [SectionID]) {
        for sectionID in sectionIDs {
            guard let sectionIndex = sectionIndex(of: sectionID) else {
                continue
            }

            sections[sectionIndex].isReloaded = true
        }
    }
}

public extension SnapshotStructure {
    struct ItemPosition {
        var item: Item
        var itemRelativeIndex: Int
        var section: Section
        var sectionIndex: Int
    }

    func sectionIndex(of sectionID: SectionID) -> Array<Section>.Index? {
        return sections.firstIndex { $0.differenceIdentifier.isEqualHash(to: sectionID) }
    }

    @discardableResult
    mutating func remove(itemID: ItemID) -> Item? {
        guard let itemPosition = itemPositionMap()[itemID] else {
            return nil
        }

        return sections[itemPosition.sectionIndex].elements.remove(at: itemPosition.itemRelativeIndex)
    }

    @discardableResult
    mutating func remove(sectionID: SectionID) -> Section? {
        guard let sectionIndex = sectionIndex(of: sectionID) else {
            return nil
        }

        return sections.remove(at: sectionIndex)
    }

    func itemPositionMap() -> [ItemID: ItemPosition] {
        return sections.enumerated().reduce(into: [:]) { result, section in
            for (itemRelativeIndex, item) in section.element.elements.enumerated() {
                result[item.differenceIdentifier] = ItemPosition(
                    item: item,
                    itemRelativeIndex: itemRelativeIndex,
                    section: section.element,
                    sectionIndex: section.offset
                )
            }
        }
    }

    func specifiedItemIsNotFound(_ id: ItemID, file: StaticString, line: UInt) -> Never {
        universalError("Specified item\(id) is not found.", file: file, line: line)
    }

    func specifiedSectionIsNotFound(_ id: SectionID, file: StaticString, line: UInt) -> Never {
        universalError("Specified section\(id) is not found.", file: file, line: line)
    }

    func thereAreCurrentlyNoSections(file: StaticString, line: UInt) -> Never {
        universalError("There are currently no sections.", file: file, line: line)
    }
}
