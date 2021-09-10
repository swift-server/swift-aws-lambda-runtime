import NIOCore

struct HTTPResponseParser {
    typealias InboundOut = APIResponse
    
    var buffer: ByteBuffer!
    
    mutating func parserAdded(context: ChannelHandlerContext) {
        self.buffer = context.channel.allocator.buffer(capacity: 1024)
    }
    
    mutating func parserRemoved(context: ChannelHandlerContext) {
        self.buffer = nil
    }
    
    mutating func channelRead(_ newBytes: inout ByteBuffer) -> APIResponse? {
        self.buffer.writeBuffer(&newBytes)
        return nil
    }
    
    mutating func decode(buffer: inout ByteBuffer) throws -> DecodingState {
        buffer.readableBytesView.withContiguousStorageIfAvailable { <#UnsafeBufferPointer<UInt8>#> in
            test.
        }
    }
    
    mutating func readStatusLine(_ buffer: inout ByteBuffer) -> Int16 {
        // HTTP/1.1 200 \r\n
        guard buffer.readableBytes >= 15 else {
            return nil
        }
        
        buffer.readableBytesView.prefix(8)
        
        buffer.withUnsafeReadableBytes { ptr in
            UnsafePointer
            
            
            test.withUTF8Buffer { testPtr -> Bool in
                guard ptr.count > testPtr else {
                    return false
                }
                
                
            }
        }
    }
}

let test: StaticString = "asdasdasdasd"
