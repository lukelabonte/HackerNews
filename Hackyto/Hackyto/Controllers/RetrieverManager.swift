//
//  RetrieverManager.swift
//  Hackyto
//
//  Created by Ernesto Torres on 5/24/15.
//  Copyright (c) 2015 ehtd. All rights reserved.
//

import Foundation

class RetrieverManager {
    
    var topStories: NSMutableArray? = nil
    var detailedStories = [String: NSDictionary]()
    
    let firebaseAPIString = "https://hacker-news.firebaseio.com/v0/topstories"
    let retrieveItemAPIString = "https://hacker-news.firebaseio.com/v0/item/"
    
    var didFinishLoadingTopStories: ((storyIDs: NSMutableArray?, stories: [String: NSDictionary]) ->())?
    var didFailedLoadingTopStories: (() ->())?
    
    var pendingDownloads: Int = 0 {
        didSet {
//            println(pendingDownloads)
            if (pendingDownloads == 0){
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    self.didFinishLoadingTopStories?(storyIDs: self.topStories, stories: self.detailedStories)
                }
                
            }
        }
    }
    
    // MARK: Retrieve Top Stories Methods
    
    func retrieveTopStories()
    {
        var topStoriesRef = Firebase(url:firebaseAPIString)
        topStoriesRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
            
            self.topStories = snapshot.value as? NSMutableArray
            self.detailedStories = [String: NSDictionary]()
            
            if (self.topStories != nil && self.topStories?.count > 0){
                self.retrieveStories(startingIndex: 0, endingIndex: (self.topStories?.count)!)
            }
            
            }, withCancelBlock: { error in
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    self.didFailedLoadingTopStories
                }
                print(error.description)
        })
    }
    
    func retrieveStories(startingIndex from:Int, endingIndex to:Int)
    {
        assert(from <= to, "From should be less than To")
        self.pendingDownloads = to-from
        if (self.topStories == nil)
        {
            return;
        }
        
        for (var i = from; i < to; i++)
        {
            let item: Int = self.topStories!.objectAtIndex(i) as! Int
            self.retrieveStoryWithId(item)
        }
    }
    
    // MARK: Retrieve single story methods
    
    func retrieveStoryWithId(storyId: Int)
    {
        // 10483024
        var itemURL = retrieveItemAPIString + "\(storyId)"
        var storyRef = Firebase(url:itemURL)
        
        storyRef.observeSingleEventOfType(.Value,
            withBlock: { snapshot in
                if snapshot.exists() == true {
                    var details = snapshot.value as! [NSString: AnyObject]
                    let key: AnyObject? = details["id"]
                    if key != nil {
                        let url = details["url"] as? String
                        
                        if (url == nil) // Ask HN does not provide base URL, use id to generate URL
                        {
                            details["url"] = Constants.hackerNewsBaseURLString+"\(key!)"
                        }

                        self.detailedStories[("\(key!)")] = details
                        self.pendingDownloads--
                    }
                } else {
                    print("FIREBASE FAILED TO RETRIEVE SNAPSHOT")
                    self.cleanStoryIdFromPendingDownloads(storyId)
                }
            },
            withCancelBlock: { error in
                print(error.description)
                self.cleanStoryIdFromPendingDownloads(storyId)
        })
    }
    
    func cleanStoryIdFromPendingDownloads(storyId: Int) {
        self.topStories!.removeObject(storyId)
        self.pendingDownloads--
    }
}

