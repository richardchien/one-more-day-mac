//
//  TodayViewController.swift
//  OneMoreDayWidget
//
//  Created by Richard Chien on 8/7/14.
//  Copyright (c) 2014 Richard Chien. All rights reserved.
//

import Cocoa
import NotificationCenter

class TodayViewController: NSViewController, NCWidgetProviding {
    
    // MARK: - View Items
    
    @IBOutlet weak var goBtn: NSButton!
    @IBOutlet weak var daysView: NSView!
    @IBOutlet weak var formNewHabitBtn: NSButton!
    
    // MARK: - Constants
    
    let kLastDateKey = "LastDate"
    let kDaysPersistedKey = "DaysPersisted"
    
    // MARK: - Variables
    
    var goBtnDisplayFrame = CGRect(), daysViewDisplayFrame = CGRect()
    var data = NSDictionary()
    var checkDateTimer = NSTimer()
    var prevResult = OMDDateCompareResult.Past
    
    // MARK: - View Load
    
    override var nibName: String! {
    return "TodayViewController"
    }
    
    override func loadView() {
        super.loadView()
        
        var size = self.preferredContentSize
        size.height = 150
        self.preferredContentSize = size
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.readOrCreateData()
        self.refreshDayLabel()
        
        let lastDate = data[kLastDateKey] as NSDate
        let nowDate = NSDate()
        prevResult = self.compareOneDay(lastDate, withAnother: nowDate) // Get current date compare result, for checkDateTimer
        
        checkDateTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("checkDateLoop"), userInfo: nil, repeats: true)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Autolayout help layout the view
        // Every time the view did layout subviews, update the frames of DaysView and GoBtn
        
        self.loadViewsAfterLayout()
    }
    
    func loadViewsAfterLayout() {
        daysViewDisplayFrame = self.daysView.frame
        goBtnDisplayFrame = self.goBtn.frame
        
        let lastDate = data[kLastDateKey] as NSDate
        let nowDate = NSDate()
        let result = self.compareOneDay(lastDate, withAnother: nowDate)
        if result == .Future {
            data = NSDictionary(objectsAndKeys: data[kLastDateKey] as NSDate, kLastDateKey,
                Int(0), kDaysPersistedKey) // Over 2 days not punch the clock, clear the days
        }
        self.refreshDayLabel()
        switch (result) {
        case .FutureOneDay, .Future:
            self.displayGoBtn()
        case .Past, .Same:
            self.displayDaysView()
        default:
            break
        }
    }
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)!) {
        // Update your data and prepare for a snapshot. Call completion handler when you are done
        // with NoData if nothing has changed or NewData if there is new data since the last
        // time we called you
        completionHandler(.NoData)
    }
    
    // MARK: - Basic Functions
    
    /*func dataFilePath() -> NSString {
    let path = NSHomeDirectory() + "/Library/Application Support/OneMoreDay"
    let fm = NSFileManager.defaultManager()
    var isDir = ObjCBool(true)
    if !(fm.fileExistsAtPath(path, isDirectory: &isDir) && isDir) {
    fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil, error: nil)
    }
    return path.stringByAppendingPathComponent("data.plist")
    }*/
    
    func yearIsLeapYear(year: Int) -> Bool {
        return ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) ? true : false
    }
    
    func checkDateLoop() {
        // This loop is to check the date's change, in order to switch views at about 00:00
        
        NSLog("Loop")
        self.readOrCreateData()
        self.refreshDayLabel()
        
        let lastDate = data[kLastDateKey] as NSDate
        let nowDate = NSDate()
        let currentResult = self.compareOneDay(lastDate, withAnother: nowDate)
        if prevResult == .Future || prevResult == .FutureOneDay {
            prevResult = currentResult
            if currentResult == .Same || currentResult == .Past {
                self.displayDaysView()
            }
        } else {
            prevResult = currentResult
            if currentResult == .Future || currentResult == .FutureOneDay {
                self.displayGoBtn()
            }
        }
    }
    
    // MARK: - Manage Data
    
    func readOrCreateData() {
        /*if NSFileManager.defaultManager().fileExistsAtPath(self.dataFilePath()) {
        data = NSDictionary(contentsOfFile: self.dataFilePath())
        } else {
        data = NSDictionary(objectsAndKeys: NSDate(timeIntervalSince1970: 0), kLastDateKey,
        Int(0), kDaysPersistedKey)
        data.writeToFile(self.dataFilePath(), atomically: true)
        }*/
        let sharedDefault = NSUserDefaults(suiteName: "group.OneMoreDaySharedDefaults")
        var lastDate = NSDate(timeIntervalSince1970: 0)
        if let time = sharedDefault.doubleForKey(kLastDateKey) as Double? {
            lastDate = NSDate(timeIntervalSince1970: time)
        }
        var days: Int = 0
        if let n = sharedDefault.integerForKey(kDaysPersistedKey) as Int? {
            days = n
        }
        
        data = NSDictionary(objectsAndKeys: lastDate, kLastDateKey, days, kDaysPersistedKey)
        self.writeData()
    }
    
    func writeData() {
        let sharedDefault = NSUserDefaults(suiteName: "group.OneMoreDaySharedDefaults")
        let lastDate = data[kLastDateKey] as NSDate
        sharedDefault.setDouble(lastDate.timeIntervalSince1970, forKey: kLastDateKey)
        sharedDefault.setInteger(data[kDaysPersistedKey] as Int, forKey: kDaysPersistedKey)
        sharedDefault.synchronize()
    }
    
    func removeData() {
        let sharedDefault = NSUserDefaults(suiteName: "group.OneMoreDaySharedDefaults")
        sharedDefault.removeObjectForKey(kLastDateKey)
        sharedDefault.removeObjectForKey(kDaysPersistedKey)
        sharedDefault.synchronize()
    }
    
    // MARK: - Date Compare
    
    enum OMDDateCompareResult: Int {
        case Past = -1
        case Same, FutureOneDay, Future
    }
    
    func compareOneDay(oneDay: NSDate, withAnother anotherDay: NSDate) -> OMDDateCompareResult {
        var df = NSDateFormatter()
        df.dateFormat = "yyyy"
        let yearStrA = NSMutableString.stringWithString(df.stringFromDate(oneDay))
        let yearStrB = NSMutableString.stringWithString(df.stringFromDate(anotherDay))
        df.dateFormat = "MM"
        let monthStrA = NSMutableString.stringWithString(df.stringFromDate(oneDay))
        let monthStrB = NSMutableString.stringWithString(df.stringFromDate(anotherDay))
        df.dateFormat = "dd"
        let dayStrA = NSMutableString.stringWithString(df.stringFromDate(oneDay))
        let dayStrB = NSMutableString.stringWithString(df.stringFromDate(anotherDay))
        
        let yearA = yearStrA.integerValue
        let yearB = yearStrB.integerValue
        let monthA = monthStrA.integerValue
        let monthB = monthStrB.integerValue
        let dayA = dayStrA.integerValue
        let dayB = dayStrB.integerValue
        
        if yearA < yearB {
            if !(monthA == 12 && monthB == 1 && dayA == 31 && dayB == 1) {
                return .Future
            } else {
                return .FutureOneDay
            }
        } else if yearA > yearB {
            return .Past
        } else {
            let lastDayOfMonth: [Int] = [31, self.yearIsLeapYear(yearA) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
            
            if monthA < monthB {
                if !(monthA == monthB - 1 && dayA == lastDayOfMonth[monthA-1] && dayB == 1) {
                    return .Future
                } else {
                    return .FutureOneDay
                }
            } else if monthA > monthB {
                return .Past
            } else {
                if dayA == dayB - 1 {
                    return .FutureOneDay
                } else if dayA < dayB - 1 {
                    return .Future
                } else if dayA == dayB {
                    return .Same
                } else {
                    return .Past
                }
            }
        }
        
        // FutureOneDay: "anotherDay" is "oneDay" + 1 day
        // Future: "anotherDay" is "oneDay" + 2 or more days
        // Same: same
        // Past: "anotherDay" is former than "oneDay"
    }
    
    // MARK: - Button Actions
    
    @IBAction func goOneMoreDay(sender: AnyObject) {
        NSLog("Go")
        // Check the date, if 2 days not punch the clock, clear the days
        let lastDate = data[kLastDateKey] as NSDate
        let nowDate = NSDate()
        let result = self.compareOneDay(lastDate, withAnother: nowDate)
        if result == .Future {
            data = NSDictionary(objectsAndKeys: data[kLastDateKey] as NSDate, kLastDateKey,
                Int(0), kDaysPersistedKey) // Over 2 days not punch the clock, clear the days
        }
        prevResult = result
        
        // Add the days and save data
        var daysPersisted = data[kDaysPersistedKey] as Int
        data = NSDictionary(objectsAndKeys: NSDate(), kLastDateKey,
            Int(daysPersisted+1), kDaysPersistedKey)
        //data.writeToFile(self.dataFilePath(), atomically: true)
        self.writeData()
        
        self.refreshDayLabel()
        self.displayDaysView()
    }
    
    @IBAction func formNewHabit(sender: AnyObject) {
        NSLog("New")
        data = NSDictionary(objectsAndKeys: NSDate(timeIntervalSince1970: 0), kLastDateKey,
            Int(0), kDaysPersistedKey)
        //data.writeToFile(self.dataFilePath(), atomically: true)
        self.writeData()
        
        self.refreshDayLabel()
        self.displayGoBtn()
    }
    
    // MARK: - Adjust Views
    
    func displayDaysView() {
        self.daysView.hidden = false
        self.goBtn.hidden = true
    }
    
    func displayGoBtn() {
        self.daysView.hidden = true
        self.goBtn.hidden = false
    }
    
    func refreshDayLabel() {
        var dayStr = NSString(format: "%d %@", data[kDaysPersistedKey] as Int, "天")
        var dayText = self.daysView.viewWithTag(1) as NSTextField
        dayText.stringValue = dayStr
    }
    
}
