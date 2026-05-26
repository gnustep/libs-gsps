/*                                                                                                                                                                                                                                     
  Copyright (C) 2013 Free Software Foundation, Inc.                                                                                                                                                                                   

  Author:  Gregory Casamento <greg.casamento@gmail.com>                                                                                                                                                                    
  Date: 2025
  This file is part of the GNUstep GUI Library.

  This library is free software; you can redistribute it and/or                                                                                                                                                                       
  modify it under the terms of the GNU Lesser General Public                                                                                                                                                                          
  License as published by the Free Software Foundation; either                                                                                                                                                                        
  version 2 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of                                                                                                                                                                   
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.
                                                                                                                                                                                                                                          
  You should have received a copy of the GNU Lesser General Public
  License along with this library; see the file COPYING.LIB. 
  If not, see <http://www.gnu.org/licenses/> or write to the
  Free Software Foundation, 51 Franklin Street, Fifth Floor,
  Boston, MA 02110-1301, USA.
*/

#import <GSPS/PSGraphicsState.h>
#import <GSPS/PSInterpreter.h>
#import <GSPS/PSRenderView.h>

@interface GSPSApplicationDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) PSRenderView *renderView;
@property (nonatomic, strong) PSInterpreter *interpreter;
@end

@implementation GSPSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  (void)notification;

  [self installMainMenu];
  [self createWindowIfNeeded];

  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  if ([arguments count] > 1)
    {
      [self loadDocumentAtPath:arguments[1]];
    }

  [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
  (void)sender;
  return YES;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
  (void)sender;
  [self createWindowIfNeeded];
  [self loadDocumentAtPath:filename];
  return YES;
}

- (void)openDocument:(id)sender
{
  (void)sender;

  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseFiles:YES];
  [panel setCanChooseDirectories:NO];
  [panel setAllowsMultipleSelection:NO];
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif
  [panel setAllowedFileTypes:@[@"ps", @"eps"]];
#if defined(__clang__)
#pragma clang diagnostic pop
#endif

  if ([panel runModal] == NSModalResponseOK)
    {
      [self createWindowIfNeeded];
      [self loadDocumentAtPath:[[panel URL] path]];
    }
}

- (void)installMainMenu
{
  NSString *appName = [[NSProcessInfo processInfo] processName];
  NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];

  NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                       action:nil
                                                keyEquivalent:@""];
  [mainMenu addItem:appMenuItem];

  NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];
  [appMenu addItemWithTitle:[NSString stringWithFormat:@"Quit %@", appName]
                     action:@selector(terminate:)
              keyEquivalent:@"q"];
  [appMenuItem setSubmenu:appMenu];

  NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                        action:nil
                                                 keyEquivalent:@""];
  [mainMenu addItem:fileMenuItem];

  NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
  NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:@"Open..."
                                                    action:@selector(openDocument:)
                                             keyEquivalent:@"o"];
  [openItem setTarget:self];
  [fileMenu addItem:openItem];
  [fileMenu addItem:[NSMenuItem separatorItem]];
  [fileMenu addItemWithTitle:@"Close"
                      action:@selector(performClose:)
               keyEquivalent:@"w"];
  [fileMenuItem setSubmenu:fileMenu];

  [NSApp setMainMenu:mainMenu];
}

- (void)createWindowIfNeeded
{
  if (_window != nil)
    {
      [_window makeKeyAndOrderFront:nil];
      return;
    }

  NSRect frame = NSMakeRect(0, 0, 640, 640);
  _window = [[NSWindow alloc] initWithContentRect:frame
                                        styleMask:(NSWindowStyleMaskTitled |
                                                   NSWindowStyleMaskClosable |
                                                   NSWindowStyleMaskResizable |
                                                   NSWindowStyleMaskMiniaturizable)
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
  [_window setTitle:@"gsps"];
  [_window center];

  _renderView = [[PSRenderView alloc] initWithFrame:frame];
  [_renderView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [_window setContentView:_renderView];
  [_window makeKeyAndOrderFront:nil];
}

- (void)loadDocumentAtPath:(NSString *)path
{
  _interpreter = [[PSInterpreter alloc] init];
  _renderView.interpreter = _interpreter;
  _interpreter.renderView = _renderView;

  [_interpreter interpretFileAtPath:path];
  [_window setTitle:[path lastPathComponent]];
  [_renderView setNeedsDisplay:YES];
}

@end

int main(int argc, const char * argv[])
{
  (void)argc;
  (void)argv;

    @autoreleasepool
      {
        NSApplication *app = [NSApplication sharedApplication];
        GSPSApplicationDelegate *delegate = [[GSPSApplicationDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
      }
    
    return 0;
}
