//
//  FetchedResultsDataSource.swift
//  YouHue
//
//  Created by Vadim Yelagin on 14/06/15.
//  Copyright (c) 2015 Fueled. All rights reserved.
//

import Foundation
import ReactiveCocoa
import CoreData

public final class FetchedResultsDataSource: DataSource {
    
    public let changes: Signal<DataChange, NoError>
    private let observer: SinkOf<Event<DataChange, NoError>>
    
    private let frc: NSFetchedResultsController
    private let frcDelegate: Delegate
    
    public init(fetchRequest: NSFetchRequest, managedObjectContext: NSManagedObjectContext, sectionNameKeyPath: String? = nil, cacheName: String? = nil) {
        (self.changes, self.observer) = Signal<DataChange, NoError>.pipe()
        self.frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
        self.frcDelegate = Delegate(observer: self.observer)
        self.frc.delegate = self.frcDelegate
    }
    
    deinit {
        self.frc.delegate = nil
        sendCompleted(self.observer)
    }
    
    private func infoForSection(section: Int) -> NSFetchedResultsSectionInfo {
        return self.frc.sections![section] as! NSFetchedResultsSectionInfo
    }
    
    public var numberOfSections: Int {
        return self.frc.sections?.count ?? 0
    }
    
    public func numberOfItemsInSection(section: Int) -> Int {
        let sectionInfo = self.infoForSection(section)
        return sectionInfo.numberOfObjects
    }
    
    public func supplementaryItemOfKind(kind: String, inSection section: Int) -> Any? {
        if kind != UICollectionElementKindSectionHeader {
            return nil
        }
        let sectionInfo = self.infoForSection(section)
        return sectionInfo.name
    }
    
    public func itemAtIndexPath(indexPath: NSIndexPath) -> Any {
        let sectionInfo = self.infoForSection(indexPath.section)
        return sectionInfo.objects[indexPath.item]
    }
    
    public func leafDataSourceAtIndexPath(indexPath: NSIndexPath) -> (DataSource, NSIndexPath) {
        return (self, indexPath)
    }
    
    private final class Delegate: NSFetchedResultsControllerDelegate {
        
        let observer: SinkOf<Event<DataChange, NoError>>
        var currentBatch: [DataChange] = []
        
        init(observer: SinkOf<Event<DataChange, NoError>>) {
            self.observer = observer
        }
        
        func controllerWillChangeContent(controller: NSFetchedResultsController) {
            self.currentBatch = []
        }
        
        func controllerDidChangeContent(controller: NSFetchedResultsController) {
            sendNext(self.observer, DataChangeBatch(self.currentBatch))
            self.currentBatch = []
        }
        
        func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
            switch type {
            case .Insert:
                self.currentBatch.append(DataChangeInsertSections(sectionIndex))
            case .Delete:
                self.currentBatch.append(DataChangeDeleteSections(sectionIndex))
            default:
                break
            }
        }
        
        func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
            switch type {
            case .Insert:
                self.currentBatch.append(DataChangeInsertItems(newIndexPath!))
            case .Delete:
                self.currentBatch.append(DataChangeDeleteItems(indexPath!))
            case .Move:
                self.currentBatch.append(DataChangeMoveItem(from: indexPath!, to: newIndexPath!))
            case .Update:
                self.currentBatch.append(DataChangeReloadItems(indexPath!))
            }
        }
        
    }
    
}