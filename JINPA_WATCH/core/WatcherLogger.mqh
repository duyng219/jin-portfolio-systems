#ifndef JINPA_WATCHER_LOGGER_MQH
#define JINPA_WATCHER_LOGGER_MQH

void WatcherLog(const string channel, const string message)
{
   Print("[JINPA_WATCH][", channel, "] ", message);
}

void WatcherLogError(const string message)
{
   WatcherLog("ERROR", message);
}

#endif
