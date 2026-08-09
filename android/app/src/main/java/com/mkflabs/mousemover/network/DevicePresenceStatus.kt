package com.mkflabs.mousemover.network

enum class DevicePresenceStatus(val title: String, val ledArgb: Long) {
    OFFLINE("Offline", 0xFFF2261F),
    SETUP("Setup", 0xFFF226D9),
    READY_TO_MOVE("Ready to move", 0xFF1EB847),
    MOVING("Moving", 0xFF1AC7D1),
    ;

    companion object {
        fun resolve(isReachable: Boolean, jiggleEnabled: Boolean, staIp: String?): DevicePresenceStatus {
            if (!isReachable) return OFFLINE
            val hasSta = !staIp.isNullOrBlank()
            if (!hasSta) return SETUP
            return if (jiggleEnabled) MOVING else READY_TO_MOVE
        }
    }
}
