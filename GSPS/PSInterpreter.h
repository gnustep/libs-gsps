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

#ifndef PSINTERPRETER_H
#define PSINTERPRETER_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class PSGraphicsState;

@interface PSInterpreter : NSObject

@property (nonatomic, strong) NSMutableArray *operandStack;
@property (nonatomic, strong) NSMutableArray *dictionaryStack;
@property (nonatomic, strong) NSMutableArray *graphicsStack;
@property (nonatomic, strong) PSGraphicsState *graphicsState;
@property (nonatomic, assign) BOOL exitFlag;
@property (nonatomic, strong) NSMutableArray *clipStack;
@property (nonatomic, strong) NSView *renderView;
@property (nonatomic, strong) NSMutableArray *renderOperations;

- (void)executeToken:(NSString *)token;
- (void)interpretString:(NSString *)source;
- (void)interpretFileAtPath:(NSString *)path;
- (void)render;

@end

#endif
