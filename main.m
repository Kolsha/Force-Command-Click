#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/NSObjCRuntime.h>
#import <Cocoa/Cocoa.h>
#import <libproc.h>

#define RequiredEvent 29
#define RequiredProcName "Google Chrome"

bool needIgnoreNextLeftMouseUp = false;



CGEventRef myCGEventCallback(CGEventTapProxy proxy,
                             CGEventType type,
                             CGEventRef eventRef,
                             void *refcon)
{
@autoreleasepool {

    if(needIgnoreNextLeftMouseUp &&
       (type == kCGEventLeftMouseUp || type == kCGEventLeftMouseDown)){
        return (NULL);
    }
    
    if ((type != RequiredEvent)){
        return eventRef;
    }


    
    NSEvent *event = [NSEvent eventWithCGEvent:eventRef];

    
    if(needIgnoreNextLeftMouseUp && event.stage != 0){
        return (NULL);
    }
    
    if(needIgnoreNextLeftMouseUp){
        needIgnoreNextLeftMouseUp = false;
        return (NULL);
    }
    
    
    char ProcName[PROC_PIDPATHINFO_MAXSIZE];
    if (!proc_name((pid_t)CGEventGetIntegerValueField(eventRef, kCGEventTargetUnixProcessID), ProcName, sizeof(ProcName))){
        return eventRef;
    }
    
    NSString *Target = [NSString stringWithUTF8String: ProcName];
    
    if (![Target isEqualToString: @RequiredProcName]){
        return eventRef;
    }
    
    if (event.type == NSEventTypePressure && event.stage == 2){
        
        if(event.pressure > 0.000){
            return (NULL);
        }
        
        
        //NSLog(@"Deep click");
        
        CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);

        CGPoint mouse_pos = CGEventGetLocation(eventRef);
        
        CGEventRef click_down = CGEventCreateMouseEvent(
                                                         src, kCGEventLeftMouseDown,
                                                         mouse_pos,
                                                         kCGMouseButtonLeft
                                                         );
        
        CGEventRef click_up = CGEventCreateMouseEvent(
                                                       src, kCGEventLeftMouseUp,
                                                       mouse_pos,
                                                       kCGMouseButtonLeft
                                                       );
        

        
        CGEventSetFlags(click_down, kCGEventFlagMaskCommand);
        CGEventSetFlags(click_up, kCGEventFlagMaskCommand);

        CGEventPost(kCGHIDEventTap, click_down);
        
        needIgnoreNextLeftMouseUp = true;

        CFRelease(src);
        CFRelease(click_down);


        return click_up;
    }
    
    return eventRef;
}
}

int main(void)
{
    CFMachPortRef      eventTap;
    CGEventMask        eventMask;
    CFRunLoopSourceRef runLoopSource;
    
    eventMask = ((1 << RequiredEvent) | (1 << kCGEventLeftMouseUp) | (1 << kCGEventLeftMouseDown));
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0,
                                eventMask, myCGEventCallback, NULL);
    if (!eventTap) {
        fprintf(stderr, "failed to create event tap\n");
        exit(1);
    }
    

    runLoopSource = CFMachPortCreateRunLoopSource(
                                                  kCFAllocatorDefault, eventTap, 0);
    

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource,
                       kCFRunLoopCommonModes);
    
    CGEventTapEnable(eventTap, true);
    
    NSLog(@"Start handling deep clicks in " RequiredProcName);
    
    CFRunLoopRun();
    
    exit(0);
}
