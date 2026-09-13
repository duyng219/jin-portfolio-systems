#ifndef JINPA_WATCHER_LOGGER_MQH
#define JINPA_WATCHER_LOGGER_MQH

void WatcherLog(const string channel, const string message)
{
   Print("[JINPA][", channel, "] ", message);
}

void WatcherLogWarning(const string message)
{
   WatcherLog("WARN", message);
}

void WatcherLogError(const string message)
{
   WatcherLog("ERROR", message);
}

#endif
