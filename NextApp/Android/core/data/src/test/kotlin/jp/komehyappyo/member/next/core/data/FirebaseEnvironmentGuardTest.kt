package jp.komehyappyo.member.next.core.data

import org.junit.Assert.assertThrows
import org.junit.Test

class FirebaseEnvironmentGuardTest {
    @Test
    fun debugBuildRejectsProductionProject() {
        assertThrows(IllegalStateException::class.java) {
            FirebaseEnvironmentGuard.requireSafeDebugProject(
                isDebug = true,
                configuredProjectId = FirebaseEnvironmentGuard.PRODUCTION_PROJECT_ID,
            )
        }
    }

    @Test
    fun debugBuildAcceptsDemoProject() {
        FirebaseEnvironmentGuard.requireSafeDebugProject(
            isDebug = true,
            configuredProjectId = "demo-org-portal-next",
        )
    }
}
