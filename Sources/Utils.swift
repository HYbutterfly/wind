import Foundation

public struct Utils {
    static func current_thread() -> UInt64 {
        UInt64(pthread_mach_thread_np(pthread_self()))
    } 
}