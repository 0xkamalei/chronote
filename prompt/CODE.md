代码用来追踪app使用时间。
```
           // 监听系统即将进入睡眠的通知
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                print("Event willSleepNotification")
                Task {
                    @MainActor in
                    ActivityManager.shared.stopTrack(modelContext: modelContext)
                }
            }

            // 监听系统从睡眠中恢复的通知
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                print("Event didWakeNotification")
                //TODO feat 是否继续上次的事件
            }
            // 监听应用激活的通知
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
                print("Event didActivateApplicationNotification")
                // 在这里执行你的回调操作
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    //print("当前激活的应用: \(app.localizedName ?? "未知")")
                    print(app.bundleIdentifier ?? "-")
                    Task {
                        @MainActor in
                        ActivityManager.shared.trackAppSwitch(newApp:  app.bundleIdentifier ?? "-", modelContext: modelContext)
                    }
                }
            }
            // 监听应用失去焦点的通知
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { notification in
                //print("Event didDeactivateApplicationNotification")
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    //print("app: \(app.localizedName ?? "未知")")
                    //print(app.bundleIdentifier ?? "-")
                }
            }
```