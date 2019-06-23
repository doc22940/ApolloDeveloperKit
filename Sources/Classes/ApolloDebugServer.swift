//
//  ApolloDebugServer.swift
//  ApolloDeveloperKit
//
//  Created by Ryosuke Ito on 6/15/19.
//  Copyright © 2019 Ryosuke Ito. All rights reserved.
//

import Apollo

// https://github.com/swisspol/GCDWebServer/issues/316
#if COCOAPODS
import GCDWebServer
#else
import GCDWebServers
#endif

public class ApolloDebugServer: DebuggableInMemoryNormalizedCacheDelegate, DebuggableNetworkTransportDelegate {
    private let server: GCDWebServer
    private let cache: DebuggableInMemoryNormalizedCache
    private let networkTransport: DebuggableNetworkTransport
    private let queryManager = QueryManager()
    private var eventStreamQueue = EventStreamQueue<GCDWebServerRequest>()
    private var timer: Timer!

    public init(cache: DebuggableInMemoryNormalizedCache, networkTransport: DebuggableNetworkTransport) {
        self.cache = cache
        self.networkTransport = networkTransport
        self.server = GCDWebServer()
        self.timer = Timer(timeInterval: 30.0, target: self, selector: #selector(timerDidFire(_:)), userInfo: nil, repeats: true)
        cache.delegate = self
        networkTransport.delegate = self
        configureHandlers()
    }

    deinit {
        stop()
    }

    public func start(port: UInt) {
        server.start(withPort: port, bonjourName: nil)
        RunLoop.current.add(timer, forMode: .default)
    }

    public func stop() {
        server.stop()
        timer.invalidate()
    }

    @objc private func timerDidFire(_ timer: Timer) {
        let ping = EventStreamChunk(data: ":".data(using: .ascii)!, error: nil)
        eventStreamQueue.enqueueForAllKeys(chunk: ping)
    }

    private func configureHandlers() {
        let documentRootPath = Bundle(for: type(of: self)).path(forResource: "Assets", ofType: nil)!
        server.addGETHandler(forBasePath: "/", directoryPath: documentRootPath, indexFilename: "index.html", cacheAge: 0, allowRangeRequests: false)
        server.addHandler(forMethod: "GET", path: "/events", request: GCDWebServerRequest.self) { [weak self] request in
            guard let self = self else {
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            self.eventStreamQueue.enqueue(chunk: self.chunkForCurrentState(), forKey: request)
            return GCDWebServerStreamedResponse(contentType: "text/event-stream", asyncStreamBlock: { [weak self] completion in
                while let self = self {
                    if let chunk = self.eventStreamQueue.dequeue(key: request) {
                        completion(chunk.data, chunk.error)
                        return
                    }
                }
                completion(Data(), nil) // finish event stream
            })
        }
        server.addHandler(forMethod: "POST", path: "/request", request: GCDWebServerDataRequest.self) { [weak self] request, completion in
            let request = request as! GCDWebServerDataRequest
            do {
                let jsonValue = try JSONSerializationFormat.deserialize(data: request.data)
                let request = try GraphQLRequest(jsonValue: jsonValue)
                _ = self?.networkTransport.send(operation: request) { response, error in
                    do {
                        if let error = error {
                            throw error
                        }
                        guard let response = response else { fatalError("response must exist when error is nil") }
                        // Cannot use JSONSerializationFormat.serialize(value:) here because
                        // response.body may contain an Objective-C type like `NSString`,
                        // that is not convertible to JSONValue directly.
                        let data = try JSONSerialization.data(withJSONObject: response.body, options: [])
                        completion(GCDWebServerDataResponse(data: data, contentType: "application/json"))
                    } catch let error {
                        completion(GCDWebServerErrorResponse(jsonObject: JSError(error: error).jsonValue))
                    }
                }
            } catch let error {
                completion(GCDWebServerErrorResponse(jsonObject: JSError(error: error).jsonValue))
            }
        }
    }

    private func chunkForCurrentState() -> EventStreamChunk {
        var data = try! JSONSerialization.data(withJSONObject: [
            "action": [:],
            "state": [
                "queries": queryManager.queryStore.store.jsonValue,
                "mutations": queryManager.mutationStore.store.jsonValue
            ],
            "dataWithOptimisticResults": cache.extract().jsonValue
            ], options: [])
        data.insert(contentsOf: "data: ".data(using: .utf8)!, at: 0)
        data.append(contentsOf: "\n\n".data(using: .utf8)!)
        return EventStreamChunk(data: data, error: nil)
    }

    // MARK: - DebuggableInMemoryNormalizedCacheDelegate

    func normalizedCache(_ normalizedCache: DebuggableInMemoryNormalizedCache, didChangeRecords records: RecordSet) {
        eventStreamQueue.enqueueForAllKeys(chunk: chunkForCurrentState())
    }

    // MARK: - DebuggableHTTPNetworkTransportDelegate

    func networkTransport<Operation>(_ networkTransport: DebuggableNetworkTransport, willSendOperation operation: Operation) where Operation : GraphQLOperation {
        if !(operation is GraphQLRequest) {
            queryManager.networkTransport(networkTransport, willSendOperation: operation)
            eventStreamQueue.enqueueForAllKeys(chunk: chunkForCurrentState())
        }
    }

    func networkTransport<Operation>(_ networkTransport: DebuggableNetworkTransport, didSendOperation operation: Operation, response: GraphQLResponse<Operation>?, error: Error?) where Operation : GraphQLOperation {
        if !(operation is GraphQLRequest) {
            queryManager.networkTransport(networkTransport, didSendOperation: operation, response: response, error: error)
            eventStreamQueue.enqueueForAllKeys(chunk: chunkForCurrentState())
        }
    }
}
