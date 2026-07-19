-- Keep failed repair attempts retryable so a route can never deadlock.
-- Every failed attempt is still recorded and the configured safety cooldown still applies.
Config.Security.maximumStopFailures = math.huge
