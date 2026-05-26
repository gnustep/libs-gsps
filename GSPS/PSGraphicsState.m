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

#import "PSGraphicsState.h"

@implementation PSGraphicsState
- (instancetype)init
{
    if (self = [super init])
      {
	_currentPoint = NSZeroPoint;
	_path = [NSBezierPath bezierPath];
	_lineWidth = 1.0;
	_strokeColor = [NSColor blackColor];
	_fillColor = [NSColor blackColor];
	_font = [NSFont systemFontOfSize:12];
	_transform = [NSAffineTransform transform];
	_clipPath = nil;
      }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  PSGraphicsState *copy = [[[self class] allocWithZone:zone] init];
  copy.currentPoint = _currentPoint;
  copy.path = [_path copy];
  copy.lineWidth = _lineWidth;
  copy.strokeColor = _strokeColor;
  copy.fillColor = _fillColor;
  copy.font = _font;
  copy.transform = [_transform copy];
  copy.clipPath = [_clipPath copy];
  return copy;
}
@end
