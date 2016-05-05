/**
 * Copyright (c) 2016-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import Foundation
import Parse
import BoltsSwift

/**
 This protocol describes the interface for handling events from a live query client.

 You can use this protocol on any custom class of yours, instead of Subscription, if it fits your use case better.
 */
@objc(PFLiveQuerySubscriptionHandling)
public protocol ObjCCompat_SubscriptionHandling {
    /**
     Tells the handler that an event has been received from the live query server.

     - parameter query: The query that the event occurred on.
     - parameter event: The event that has been recieved from the server.
     - parameter client: The live query client which received this event.
     */
    @objc(liveQuery:didRecieveEvent:inClient:)
    optional func didRecieveEvent(query: PFQuery, event: ObjCCompat.Event, client: Client)

    /**
     Tells the handler that an error has been received from the live query server.

     - parameter query: The query that the error occurred on.
     - parameter error: The error that the server has encountered.
     - parameter client: The live query client which received this error.
     */
    @objc(liveQuery:didEncounterError:inClient:)
    optional func didRecieveError(query: PFQuery, error: NSError, client: Client)

    /**
     Tells the handler that a query has been successfully registered with the server.

     - note: This may be invoked multiple times if the client disconnects/reconnects.

     - parameter query: The query that has been subscribed.
     - parameter client: The live query client which subscribed this query.
     */
    @objc(liveQuery:didSubscribeInClient:)
    optional func didSubscribe(query: PFQuery, client: Client)

    /**
     Tells the handler that a query has been successfully deregistered from the server.

     - note: This is not called unless `unregister()` is explicitly called.

     - parameter query: The query that has been unsubscribed.
     - parameter client: The live query client which unsubscribed this query.
     */
    @objc(liveQuery:didUnsubscribeInClient:)
    optional func didUnsubscribe(query: PFQuery, client: Client)
}

// HACK: Compiler bug causes enums that are declared in structs that are marked as @objc to not actually be emitted by 
// the compiler (lolwut?). Moving this to global scope fixes the problem, but we can't change the objc name of an enum
// either, so we pollute the swift namespace here.
// TODO: Fix this eventually.

/**
 A type of an update event on a specific object from the live query server.
 */
@objc
public enum PFLiveQueryEventType: Int {
    /// The object has been updated, and is now included in the query.
    case Entered
    /// The object has been updated, and is no longer included in the query.
    case Left
    /// The object has been created, and is a part of the query.
    case Created
    /// The object has been updated, and is still a part of the query.
    case Updated
    /// The object has been deleted, and is no longer included in the query.
    case Deleted
}

/**
 This struct wraps up all of our Objective-C compatibility layer. You should never need to touch this if you're using Swift.
 */
public struct ObjCCompat {
    private init() { }

    /**
      Represents an update on a specific object from the live query server.
     */
    @objc(PFLiveQueryEvent)
    public class Event: NSObject {
        /// Type of the event.
        @objc
        public let type: PFLiveQueryEventType

        /// Object this event is for.
        @objc
        public let object: PFObject

        init(type: PFLiveQueryEventType, object: PFObject) {
            self.type = type
            self.object = object
        }
    }

    /**
     A default implementation of the SubscriptionHandling protocol, using blocks for callbacks.
     */
    @objc(PFLiveQuerySubscription)
    public class Subscription: NSObject {
        public typealias SubscribeHandler = @convention(block) PFQuery -> Void
        public typealias ErrorHandler = @convention(block) (PFQuery, NSError) -> Void
        public typealias EventHandler = @convention(block) (PFQuery, Event) -> Void
        public typealias ObjectHandler = @convention(block) (PFQuery, PFObject) -> Void

        var subscribeHandlers = [SubscribeHandler]()
        var unsubscribeHandlers = [SubscribeHandler]()
        var errorHandlers = [ErrorHandler]()
        var eventHandlers = [EventHandler]()

        /**
         Register a callback for when a client succesfully subscribes to a query.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addSubscribeHandler(handler: SubscribeHandler) -> Subscription {
            subscribeHandlers.append(handler)
            return self
        }

        /**
         Register a callback for when a query has been unsubscribed.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addUnsubscribeHandler(handler: SubscribeHandler) -> Subscription {
            unsubscribeHandlers.append(handler)
            return self
        }

        /**
         Register a callback for when an error occurs.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addErrorHandler(handler: ErrorHandler) -> Subscription {
            errorHandlers.append(handler)
            return self
        }

        /**
         Register a callback for when an event occurs.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addEventHandler(handler: EventHandler) -> Subscription {
            eventHandlers.append(handler)
            return self
        }

        /**
         Register a callback for when an object enters a query.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addEnterHandler(handler: ObjectHandler) -> Subscription {
            return addEventHandler { $1.type == .Entered ? handler($0, $1.object) : () }
        }

        /**
         Register a callback for when an object leaves a query.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addLeaveHandler(handler: ObjectHandler) -> Subscription {
            return addEventHandler { $1.type == .Left ? handler($0, $1.object) : () }
        }

        /**
         Register a callback for when an object that matches the query is created.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addCreateHandler(handler: ObjectHandler) -> Subscription {
            return addEventHandler { $1.type == .Created ? handler($0, $1.object) : () }
        }

        /**
         Register a callback for when an object that matches the query is updated.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addUpdateHandler(handler: ObjectHandler) -> Subscription {
            return addEventHandler { $1.type == .Updated ? handler($0, $1.object) : () }
        }

        /**
         Register a callback for when an object that matches the query is deleted.

         - parameter handler: The callback to register.

         - returns: The same subscription, for easy chaining.
         */
        public func addDeleteHandler(handler: ObjectHandler) -> Subscription {
            return addEventHandler { $1.type == .Deleted ? handler($0, $1.object) : () }
        }
    }
}

extension ObjCCompat.Subscription: ObjCCompat_SubscriptionHandling {
    func didRecieveEvent(query: PFQuery, event: ObjCCompat.Event, client: Client) {
        eventHandlers.forEach { $0(query, event) }
    }

    func didRecieveError(query: PFQuery, error: NSError, client: Client) {
        errorHandlers.forEach { $0(query, error) }
    }

    func didSubscribe(query: PFQuery, client: Client) {
        subscribeHandlers.forEach { $0(query) }
    }

    func didUnsubscribe(query: PFQuery, client: Client) {
        unsubscribeHandlers.forEach { $0(query) }
    }
}

extension ObjCCompat.Subscription: SubscriptionHandling {
    
    public typealias PFObjectSubclass = PFObject
    
    public func didReceive(event: Event<PFObjectSubclass>, forQuery query: PFQuery, inClient client: Client) {
        self.didRecieveEvent(query, event: ObjCCompat.Event(event: event), client: client)
    }
    
    public func didEncounter(error: ErrorType, forQuery query: PFQuery, inClient client: Client) {
        self.didRecieveError(query, error: error as NSError, client: client)
    }
    
    public func didSubscribe(toQuery query: PFQuery, inClient client: Client) {
        self.didSubscribe(query, client: client)
    }
    
    public func didUnsubscribe(fromQuery query: PFQuery, inClient client: Client) {
        self.didUnsubscribe(query, client: client)
    }
}

extension Client {
    
    /**
     Registers a query for live updates, using the default subscription handler.

     - parameter query: The query to register for updates.

     - returns: The subscription that has just been registered.
     */
    @objc(subscribeToQuery:)
    public func _PF_objc_subscribe(query: PFQuery) -> ObjCCompat.Subscription {
        let subscription = ObjCCompat.Subscription()
        subscribe(query, handler: subscription)
        return subscription
    }

    /**
     Unsubscribes a specific handler from a query.

     - parameter query: The query to unsubscribe from.
     - parameter handler: The specific handler to unsubscribe from.
     */
    @objc(unsubscribeFromQuery:withHandler:)
    public func _PF_objc_unsubscribe(query: PFQuery, subscriptionHandler: ObjCCompat_SubscriptionHandling) {
        unsubscribe { record in
            return record.query == query && record.subscriptionHandler === subscriptionHandler
        }
    }
}

// HACK: Another compiler bug - if you have a required initializer with a generic type, the compiler simply refuses to 
// emit the entire class altogether. Moving this to an extension for now solves the issue.

extension ObjCCompat.Event {
    convenience init<T>(event: ParseLiveQuery.Event<T>) {
        let results: (type: PFLiveQueryEventType, object: PFObject) = {
            switch event {
            case .Entered(let object): return (.Entered, object)
            case .Left(let object):    return (.Left, object)
            case .Created(let object): return (.Created, object)
            case .Updated(let object): return (.Updated, object)
            case .Deleted(let object): return (.Deleted, object)
            }
        }()

        self.init(type: results.type, object: results.object)
    }
}

extension PFQuery {
    /**
     Register this PFQuery for updates with Live Queries.
     This uses the shared live query client, and creates a default subscription handler for you.

     - returns: The created subscription for observing.
     */
    @objc(subscribe)
    public func _PF_objc_subscribe() -> ObjCCompat.Subscription {
        return Client.shared._PF_objc_subscribe(self)
    }
}
