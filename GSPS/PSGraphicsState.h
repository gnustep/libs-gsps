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

#ifndef PSGRAPHICS_STATE_H
#define PSGRAPHICS_STATE_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface PSGraphicsState : NSObject <NSCopying>

@property (nonatomic) NSPoint currentPoint;
@property (nonatomic, strong) NSBezierPath *path;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, strong) NSColor *strokeColor;
@property (nonatomic, strong) NSColor *fillColor;
@property (nonatomic, strong) NSFont *font;
@property (nonatomic, strong) NSAffineTransform *transform;
@property (nonatomic, strong) NSBezierPath *clipPath;

@end

#endif
