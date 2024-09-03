//
//  ActorTest.swift
//  swift-aws-lambda-runtime
//
//  Created by Fabian Fett on 03.09.24.
//

import Testing
import NIOCore
import NIOPosix

final actor EventLoopActor {
    nonisolated let unownedExecutor: UnownedSerialExecutor
    private let eventLoop: any EventLoop

    init(eventLoop: any EventLoop) {
        self.unownedExecutor = eventLoop.executor.asUnownedSerialExecutor()
        self.eventLoop = eventLoop
    }

    func haha() {
        _ = self.eventLoop.execute {
            self.assumeIsolated { this in // crashes here!
                print(this.eventLoop)
            }
        }
    }
}

@Suite
struct ActorTest {

    @Test
    func testEventLoopAsCustomSerialExecutor() async {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let actor = EventLoopActor(eventLoop: elg.next())

        await actor.haha()

        try? await elg.shutdownGracefully()
    }
}

