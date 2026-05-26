/*
  Copyright (C) 2013 Free Software Foundation, Inc.

  Author:  Gregory Casamento <greg.casamento@gmail.com>
  Date: 2025
  This file is part of the GNUstep GUI Library.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.
*/

#import "PSInterpreter.h"
#import "PSGraphicsState.h"

#include <ctype.h>
#include <math.h>

@interface PSName : NSObject <NSCopying>
@property (nonatomic, copy) NSString *value;
@property (nonatomic) BOOL literal;
+ (instancetype)nameWithString:(NSString *)value literal:(BOOL)literal;
@end

@implementation PSName
+ (instancetype)nameWithString:(NSString *)value literal:(BOOL)literal
{
  PSName *name = [[self alloc] init];
  name.value = value;
  name.literal = literal;
  return name;
}
- (id)copyWithZone:(NSZone *)zone
{
  return [PSName nameWithString:_value literal:_literal];
}
- (NSString *)description
{
  return _literal ? [@"/" stringByAppendingString:_value] : _value;
}
@end

@interface PSProcedure : NSObject <NSCopying>
@property (nonatomic, strong) NSArray *objects;
+ (instancetype)procedureWithObjects:(NSArray *)objects;
@end

@implementation PSProcedure
+ (instancetype)procedureWithObjects:(NSArray *)objects
{
  PSProcedure *procedure = [[self alloc] init];
  procedure.objects = objects;
  return procedure;
}
- (id)copyWithZone:(NSZone *)zone
{
  return [PSProcedure procedureWithObjects:[[NSArray alloc] initWithArray:_objects copyItems:YES]];
}
- (NSString *)description
{
  return [NSString stringWithFormat:@"{%@}", [_objects componentsJoinedByString:@" "]];
}
@end

@interface PSRenderOperation : NSObject
@property (nonatomic, copy) NSString *type;
@property (nonatomic, strong) NSBezierPath *path;
@property (nonatomic, strong) NSColor *strokeColor;
@property (nonatomic, strong) NSColor *fillColor;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, strong) NSBezierPath *clipPath;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSFont *font;
@property (nonatomic) NSPoint point;
@property (nonatomic) NSRect rect;
@property (nonatomic, strong) NSImage *image;
- (void)render;
@end

@implementation PSRenderOperation
- (void)render
{
  [NSGraphicsContext saveGraphicsState];
  if (_clipPath != nil)
    {
      [_clipPath addClip];
    }

  if ([_type isEqualToString:@"stroke"])
    {
      [_strokeColor setStroke];
      [_path setLineWidth:_lineWidth];
      [_path stroke];
    }
  else if ([_type isEqualToString:@"fill"])
    {
      [_fillColor setFill];
      [_path fill];
    }
  else if ([_type isEqualToString:@"eofill"])
    {
      [_fillColor setFill];
      [_path setWindingRule:NSEvenOddWindingRule];
      [_path fill];
    }
  else if ([_type isEqualToString:@"rectfill"])
    {
      [_fillColor setFill];
      [NSBezierPath fillRect:_rect];
    }
  else if ([_type isEqualToString:@"rectstroke"])
    {
      NSBezierPath *path = [NSBezierPath bezierPathWithRect:_rect];
      [_strokeColor setStroke];
      [path setLineWidth:_lineWidth];
      [path stroke];
    }
  else if ([_type isEqualToString:@"show"])
    {
      NSDictionary *attrs = @{
        NSFontAttributeName: _font ?: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: _strokeColor ?: [NSColor blackColor]
      };
      [_text drawAtPoint:_point withAttributes:attrs];
    }
  else if ([_type isEqualToString:@"image"])
    {
      [_image drawAtPoint:_point fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    }
  [NSGraphicsContext restoreGraphicsState];
}
@end

@interface PSParser : NSObject
@property (nonatomic, copy) NSString *source;
@property (nonatomic) NSUInteger index;
- (instancetype)initWithString:(NSString *)source;
- (NSArray *)parse;
@end

@implementation PSParser
- (instancetype)initWithString:(NSString *)source
{
  if ((self = [super init]))
    {
      _source = source ?: @"";
      _index = 0;
    }
  return self;
}

- (NSArray *)parse
{
  NSMutableArray *objects = [NSMutableArray array];
  id object = nil;
  while ((object = [self parseObjectUntil:nil]) != nil)
    {
      [objects addObject:object];
    }
  return objects;
}

- (unichar)peek
{
  return (_index < [_source length]) ? [_source characterAtIndex:_index] : 0;
}

- (unichar)get
{
  return (_index < [_source length]) ? [_source characterAtIndex:_index++] : 0;
}

- (void)skipWhitespaceAndComments
{
  while (_index < [_source length])
    {
      unichar c = [self peek];
      if (c == '%')
        {
          while (_index < [_source length] && [self peek] != '\n' && [self peek] != '\r')
            {
              _index++;
            }
        }
      else if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c])
        {
          _index++;
        }
      else
        {
          break;
        }
    }
}

- (BOOL)isDelimiter:(unichar)c
{
  return c == 0 || isspace((int)c) || c == '(' || c == ')' || c == '<' || c == '>' ||
    c == '[' || c == ']' || c == '{' || c == '}' || c == '/' || c == '%';
}

- (id)parseObjectUntil:(NSString *)terminator
{
  [self skipWhitespaceAndComments];
  if (_index >= [_source length])
    {
      return nil;
    }

  unichar c = [self peek];
  if (terminator != nil && [terminator length] == 1 && c == [terminator characterAtIndex:0])
    {
      _index++;
      return nil;
    }
  if (c == ')' || c == ']' || c == '}')
    {
      _index++;
      return nil;
    }
  if (c == '>')
    {
      if (_index + 1 < [_source length] && [_source characterAtIndex:_index + 1] == '>')
        {
          _index += 2;
          return @">>";
        }
      _index++;
      return nil;
    }

  if (c == '(')
    {
      return [self parseString];
    }
  if (c == '/')
    {
      return [self parseName:YES];
    }
  if (c == '[')
    {
      return [self parseArray];
    }
  if (c == '{')
    {
      return [self parseProcedure];
    }
  if (c == '<')
    {
      return [self parseAngleObject];
    }
  return [self parseAtom];
}

- (NSString *)parseString
{
  NSMutableString *result = [NSMutableString string];
  NSInteger depth = 0;
  [self get];
  depth++;
  while (_index < [_source length] && depth > 0)
    {
      unichar c = [self get];
      if (c == '\\')
        {
          if (_index >= [_source length])
            {
              break;
            }
          unichar e = [self get];
          switch (e)
            {
              case 'n': [result appendString:@"\n"]; break;
              case 'r': [result appendString:@"\r"]; break;
              case 't': [result appendString:@"\t"]; break;
              case 'b': [result appendString:@"\b"]; break;
              case 'f': [result appendString:@"\f"]; break;
              case '\n': case '\r': break;
              default:
                if (e >= '0' && e <= '7')
                  {
                    int value = e - '0';
                    int count = 1;
                    while (count < 3 && _index < [_source length])
                      {
                        unichar o = [self peek];
                        if (o < '0' || o > '7') break;
                        value = value * 8 + ([self get] - '0');
                        count++;
                      }
                    [result appendFormat:@"%c", value & 0xff];
                  }
                else
                  {
                    [result appendFormat:@"%C", e];
                  }
            }
        }
      else if (c == '(')
        {
          depth++;
          [result appendString:@"("];
        }
      else if (c == ')')
        {
          depth--;
          if (depth > 0)
            {
              [result appendString:@")"];
            }
        }
      else
        {
          [result appendFormat:@"%C", c];
        }
    }
  return result;
}

- (PSName *)parseName:(BOOL)literal
{
  if (literal)
    {
      [self get];
    }
  NSUInteger start = _index;
  while (_index < [_source length] && ![self isDelimiter:[self peek]])
    {
      _index++;
    }
  NSString *name = [_source substringWithRange:NSMakeRange(start, _index - start)];
  return [PSName nameWithString:name literal:literal];
}

- (NSArray *)parseArray
{
  NSMutableArray *objects = [NSMutableArray array];
  [self get];
  id object = nil;
  while ((object = [self parseObjectUntil:@"]"]) != nil)
    {
      [objects addObject:object];
    }
  return objects;
}

- (PSProcedure *)parseProcedure
{
  NSMutableArray *objects = [NSMutableArray array];
  [self get];
  id object = nil;
  while ((object = [self parseObjectUntil:@"}"]) != nil)
    {
      [objects addObject:object];
    }
  return [PSProcedure procedureWithObjects:objects];
}

- (id)parseAngleObject
{
  [self get];
  if ([self peek] == '<')
    {
      [self get];
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      NSMutableArray *items = [NSMutableArray array];
      id object = nil;
      while ((object = [self parseObjectUntil:nil]) != nil)
        {
          if ([object isKindOfClass:[NSString class]] && [object isEqualToString:@">>"])
            {
              break;
            }
          [items addObject:object];
        }
      for (NSUInteger i = 0; i + 1 < [items count]; i += 2)
        {
          id key = items[i];
          if ([key isKindOfClass:[PSName class]])
            {
              dict[((PSName *)key).value] = items[i + 1];
            }
        }
      return dict;
    }

  NSMutableString *hex = [NSMutableString string];
  while (_index < [_source length])
    {
      unichar c = [self get];
      if (c == '>')
        {
          break;
        }
      if (!isspace((int)c))
        {
          [hex appendFormat:@"%C", c];
        }
    }
  if ([hex length] % 2 == 1)
    {
      [hex appendString:@"0"];
    }
  NSMutableData *data = [NSMutableData dataWithCapacity:[hex length] / 2];
  for (NSUInteger i = 0; i + 1 < [hex length]; i += 2)
    {
      unsigned value = 0;
      NSString *byteString = [hex substringWithRange:NSMakeRange(i, 2)];
      [[NSScanner scannerWithString:byteString] scanHexInt:&value];
      unsigned char byte = value & 0xff;
      [data appendBytes:&byte length:1];
    }
  return data;
}

- (id)parseAtom
{
  NSUInteger start = _index;
  while (_index < [_source length] && ![self isDelimiter:[self peek]])
    {
      _index++;
    }
  NSString *atom = [_source substringWithRange:NSMakeRange(start, _index - start)];
  if ([atom isEqualToString:@">>"])
    {
      return atom;
    }

  char *end = NULL;
  double value = strtod([atom UTF8String], &end);
  if (end != NULL && *end == '\0' && [atom length] > 0 &&
      (isdigit((int)[atom characterAtIndex:0]) || [atom hasPrefix:@"-"] || [atom hasPrefix:@"+"] || [atom hasPrefix:@"."]))
    {
      return @(value);
    }
  return [PSName nameWithString:atom literal:NO];
}
@end

@implementation PSInterpreter

- (instancetype)init
{
  if ((self = [super init]))
    {
      _operandStack = [NSMutableArray array];
      _dictionaryStack = [NSMutableArray arrayWithObject:[NSMutableDictionary dictionary]];
      _graphicsStack = [NSMutableArray array];
      _graphicsState = [[PSGraphicsState alloc] init];
      _clipStack = [NSMutableArray array];
      _renderOperations = [NSMutableArray array];
      _exitFlag = NO;
    }
  return self;
}

- (id)pop
{
  id value = [_operandStack lastObject];
  if (value == nil)
    {
      NSLog(@"PostScript stack underflow");
      return nil;
    }
  [_operandStack removeLastObject];
  return value;
}

- (NSNumber *)popNumber
{
  id value = [self pop];
  return [value isKindOfClass:[NSNumber class]] ? value : @0;
}

- (NSString *)keyForName:(id)obj
{
  if ([obj isKindOfClass:[PSName class]])
    {
      return ((PSName *)obj).value;
    }
  return [obj description];
}

- (id)lookupName:(NSString *)name
{
  for (NSDictionary *dict in [_dictionaryStack reverseObjectEnumerator])
    {
      id value = dict[name];
      if (value != nil)
        {
          return value;
        }
    }
  return nil;
}

- (void)executeObjects:(NSArray *)objects
{
  for (id object in objects)
    {
      if (_exitFlag)
        {
          break;
        }
      [self executeObject:object];
    }
}

- (void)executeObject:(id)object
{
  if (object == nil || _exitFlag)
    {
      return;
    }
  if ([object isKindOfClass:[PSName class]])
    {
      PSName *name = object;
      if (name.literal)
        {
          [_operandStack addObject:name];
          return;
        }

      id value = [self lookupName:name.value];
      if (value != nil)
        {
          if ([value isKindOfClass:[PSProcedure class]])
            {
              [self executeObjects:((PSProcedure *)value).objects];
            }
          else
            {
              [_operandStack addObject:value];
            }
          return;
        }
      [self executeOperator:name.value];
      return;
    }
  [_operandStack addObject:object];
}

- (void)executeToken:(NSString *)token
{
  PSParser *parser = [[PSParser alloc] initWithString:token];
  [self executeObjects:[parser parse]];
}

- (void)interpretString:(NSString *)source
{
  _exitFlag = NO;
  PSParser *parser = [[PSParser alloc] initWithString:source];
  [self executeObjects:[parser parse]];
}

- (void)interpretFileAtPath:(NSString *)path
{
  NSError *error = nil;
  NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
  if (content == nil)
    {
      content = [NSString stringWithContentsOfFile:path encoding:NSISOLatin1StringEncoding error:&error];
    }
  if (content == nil)
    {
      NSLog(@"Error reading file: %@", error);
      return;
    }
  [self interpretString:content];
}

- (void)render
{
  for (PSRenderOperation *operation in _renderOperations)
    {
      [operation render];
    }
}

- (NSPoint)transformPointX:(NSNumber *)x y:(NSNumber *)y
{
  return [_graphicsState.transform transformPoint:NSMakePoint([x doubleValue], [y doubleValue])];
}

- (void)addPaintOperation:(NSString *)type path:(NSBezierPath *)path
{
  PSRenderOperation *operation = [[PSRenderOperation alloc] init];
  operation.type = type;
  operation.path = [path copy];
  operation.strokeColor = _graphicsState.strokeColor;
  operation.fillColor = _graphicsState.fillColor;
  operation.lineWidth = _graphicsState.lineWidth;
  operation.clipPath = [_graphicsState.clipPath copy];
  [_renderOperations addObject:operation];
}

- (NSFont *)fontFromObject:(id)obj size:(CGFloat)size
{
  if ([obj isKindOfClass:[NSFont class]])
    {
      NSFontDescriptor *descriptor = [obj fontDescriptor];
      return [NSFont fontWithDescriptor:descriptor size:size] ?: obj;
    }
  NSString *name = [self keyForName:obj];
  if ([name hasPrefix:@"/"])
    {
      name = [name substringFromIndex:1];
    }
  return [NSFont fontWithName:name size:size] ?: [NSFont systemFontOfSize:size];
}

- (NSAffineTransform *)transformFromMatrixObject:(id)obj
{
  if ([obj isKindOfClass:[NSAffineTransform class]])
    {
      return obj;
    }
  if ([obj isKindOfClass:[NSArray class]] && [obj count] >= 6)
    {
      NSAffineTransformStruct s;
      s.m11 = [obj[0] doubleValue];
      s.m12 = [obj[1] doubleValue];
      s.m21 = [obj[2] doubleValue];
      s.m22 = [obj[3] doubleValue];
      s.tX = [obj[4] doubleValue];
      s.tY = [obj[5] doubleValue];
      NSAffineTransform *transform = [NSAffineTransform transform];
      [transform setTransformStruct:s];
      return transform;
    }
  return nil;
}

- (NSMutableArray *)matrixArrayFromTransform:(NSAffineTransform *)transform
{
  NSAffineTransformStruct s = [transform transformStruct];
  return [NSMutableArray arrayWithObjects:@(s.m11), @(s.m12), @(s.m21), @(s.m22), @(s.tX), @(s.tY), nil];
}

- (void)executeOperator:(NSString *)token
{
  if ([token isEqualToString:@"true"])
    {
      [_operandStack addObject:@YES];
    }
  else if ([token isEqualToString:@"false"])
    {
      [_operandStack addObject:@NO];
    }
  else if ([token isEqualToString:@"null"])
    {
      [_operandStack addObject:[NSNull null]];
    }
  else if ([token isEqualToString:@"add"] || [token isEqualToString:@"sub"] ||
           [token isEqualToString:@"mul"] || [token isEqualToString:@"div"] ||
           [token isEqualToString:@"mod"])
    {
      NSNumber *b = [self popNumber];
      NSNumber *a = [self popNumber];
      double result = 0.0;
      if ([token isEqualToString:@"add"]) result = [a doubleValue] + [b doubleValue];
      else if ([token isEqualToString:@"sub"]) result = [a doubleValue] - [b doubleValue];
      else if ([token isEqualToString:@"mul"]) result = [a doubleValue] * [b doubleValue];
      else if ([token isEqualToString:@"div"]) result = [a doubleValue] / [b doubleValue];
      else result = fmod([a doubleValue], [b doubleValue]);
      [_operandStack addObject:@(result)];
    }
  else if ([token isEqualToString:@"neg"] || [token isEqualToString:@"abs"] ||
           [token isEqualToString:@"sqrt"] || [token isEqualToString:@"sin"] ||
           [token isEqualToString:@"cos"])
    {
      NSNumber *a = [self popNumber];
      double v = [a doubleValue];
      if ([token isEqualToString:@"neg"]) v = -v;
      else if ([token isEqualToString:@"abs"]) v = fabs(v);
      else if ([token isEqualToString:@"sqrt"]) v = sqrt(v);
      else if ([token isEqualToString:@"sin"]) v = sin(v * M_PI / 180.0);
      else v = cos(v * M_PI / 180.0);
      [_operandStack addObject:@(v)];
    }
  else if ([token isEqualToString:@"eq"] || [token isEqualToString:@"=="])
    {
      id b = [self pop];
      id a = [self pop];
      [_operandStack addObject:@([a isEqual:b])];
    }
  else if ([token isEqualToString:@"ne"])
    {
      id b = [self pop];
      id a = [self pop];
      [_operandStack addObject:@(![a isEqual:b])];
    }
  else if ([token isEqualToString:@"gt"] || [token isEqualToString:@"lt"] ||
           [token isEqualToString:@"ge"] || [token isEqualToString:@"le"])
    {
      NSNumber *b = [self popNumber];
      NSNumber *a = [self popNumber];
      BOOL result = NO;
      if ([token isEqualToString:@"gt"]) result = [a doubleValue] > [b doubleValue];
      else if ([token isEqualToString:@"lt"]) result = [a doubleValue] < [b doubleValue];
      else if ([token isEqualToString:@"ge"]) result = [a doubleValue] >= [b doubleValue];
      else result = [a doubleValue] <= [b doubleValue];
      [_operandStack addObject:@(result)];
    }
  else if ([token isEqualToString:@"and"] || [token isEqualToString:@"or"])
    {
      NSNumber *b = [self popNumber];
      NSNumber *a = [self popNumber];
      [_operandStack addObject:[token isEqualToString:@"and"] ? @([a boolValue] && [b boolValue]) : @([a boolValue] || [b boolValue])];
    }
  else if ([token isEqualToString:@"not"])
    {
      NSNumber *a = [self popNumber];
      [_operandStack addObject:@(![a boolValue])];
    }
  else if ([token isEqualToString:@"dup"])
    {
      id top = [_operandStack lastObject];
      if (top != nil) [_operandStack addObject:top];
    }
  else if ([token isEqualToString:@"exch"])
    {
      id b = [self pop];
      id a = [self pop];
      if (b && a)
        {
          [_operandStack addObject:b];
          [_operandStack addObject:a];
        }
    }
  else if ([token isEqualToString:@"pop"])
    {
      [self pop];
    }
  else if ([token isEqualToString:@"clear"])
    {
      [_operandStack removeAllObjects];
    }
  else if ([token isEqualToString:@"count"])
    {
      [_operandStack addObject:@([_operandStack count])];
    }
  else if ([token isEqualToString:@"index"])
    {
      NSInteger index = [[self popNumber] integerValue];
      NSUInteger count = [_operandStack count];
      if (index >= 0 && (NSUInteger)index < count)
        {
          [_operandStack addObject:_operandStack[count - index - 1]];
        }
    }
  else if ([token isEqualToString:@"copy"])
    {
      id value = [self pop];
      if ([value isKindOfClass:[NSNumber class]])
        {
          NSInteger count = [value integerValue];
          NSUInteger stackCount = [_operandStack count];
          if (count > 0 && (NSUInteger)count <= stackCount)
            {
              NSArray *tail = [_operandStack subarrayWithRange:NSMakeRange(stackCount - count, count)];
              [_operandStack addObjectsFromArray:tail];
            }
        }
      else if ([value respondsToSelector:@selector(mutableCopy)])
        {
          [_operandStack addObject:[value mutableCopy]];
        }
      else if (value != nil)
        {
          [_operandStack addObject:value];
        }
    }
  else if ([token isEqualToString:@"stack"] || [token isEqualToString:@"pstack"])
    {
      NSLog(@"--- Stack ---");
      for (id object in [_operandStack reverseObjectEnumerator])
        {
          NSLog(@"%@", object);
        }
    }
  else if ([token isEqualToString:@"="] || [token isEqualToString:@"print"])
    {
      NSLog(@"%@", [self pop]);
    }
  else if ([token isEqualToString:@"array"])
    {
      NSInteger count = [[self popNumber] integerValue];
      NSMutableArray *array = [NSMutableArray arrayWithCapacity:MAX(count, 0)];
      for (NSInteger i = 0; i < count; i++) [array addObject:[NSNull null]];
      [_operandStack addObject:array];
    }
  else if ([token isEqualToString:@"length"])
    {
      id obj = [self pop];
      if ([obj respondsToSelector:@selector(length)])
        [_operandStack addObject:@([obj length])];
      else if ([obj respondsToSelector:@selector(count)])
        [_operandStack addObject:@([obj count])];
    }
  else if ([token isEqualToString:@"get"])
    {
      id key = [self pop];
      id container = [self pop];
      if ([container isKindOfClass:[NSArray class]])
        [_operandStack addObject:container[[key integerValue]]];
      else if ([container isKindOfClass:[NSDictionary class]])
        [_operandStack addObject:container[[self keyForName:key]] ?: [NSNull null]];
      else if ([container isKindOfClass:[NSString class]])
        [_operandStack addObject:@([(NSString *)container characterAtIndex:[key integerValue]])];
    }
  else if ([token isEqualToString:@"put"])
    {
      id value = [self pop];
      id key = [self pop];
      id container = [self pop];
      if ([container isKindOfClass:[NSMutableArray class]])
        ((NSMutableArray *)container)[[key integerValue]] = value;
      else if ([container isKindOfClass:[NSMutableDictionary class]])
        ((NSMutableDictionary *)container)[[self keyForName:key]] = value;
    }
  else if ([token isEqualToString:@"aload"])
    {
      id array = [self pop];
      if ([array isKindOfClass:[NSArray class]])
        {
          [_operandStack addObjectsFromArray:array];
          [_operandStack addObject:array];
        }
    }
  else if ([token isEqualToString:@"astore"])
    {
      NSMutableArray *array = [self pop];
      for (NSInteger i = [array count] - 1; i >= 0; i--)
        {
          array[i] = [self pop] ?: [NSNull null];
        }
      [_operandStack addObject:array];
    }
  else if ([token isEqualToString:@"substring"])
    {
      NSInteger length = [[self popNumber] integerValue];
      NSInteger start = [[self popNumber] integerValue];
      NSString *string = [self pop];
      if (start >= 0 && length >= 0 && start + length <= (NSInteger)[string length])
        [_operandStack addObject:[string substringWithRange:NSMakeRange(start, length)]];
      else
        [_operandStack addObject:@""];
    }
  else if ([token isEqualToString:@"concat"])
    {
      id b = [self pop];
      NSAffineTransform *matrix = [self transformFromMatrixObject:b];
      if (matrix != nil)
        {
          [_graphicsState.transform appendTransform:matrix];
        }
      else
        {
          id a = [self pop];
          [_operandStack addObject:[[a description] stringByAppendingString:[b description]]];
        }
    }
  else if ([token isEqualToString:@"token"])
    {
      NSString *string = [self pop];
      PSParser *parser = [[PSParser alloc] initWithString:string];
      NSArray *objects = [parser parse];
      if ([objects count] > 0)
        {
          [_operandStack addObject:objects[0]];
          [_operandStack addObject:@""];
          [_operandStack addObject:@YES];
        }
      else
        {
          [_operandStack addObject:@NO];
        }
    }
  else if ([token isEqualToString:@"dict"])
    {
      [self pop];
      [_operandStack addObject:[NSMutableDictionary dictionary]];
    }
  else if ([token isEqualToString:@"begin"])
    {
      id dict = [self pop];
      if ([dict isKindOfClass:[NSMutableDictionary class]])
        [_dictionaryStack addObject:dict];
      else if ([dict isKindOfClass:[NSDictionary class]])
        [_dictionaryStack addObject:[dict mutableCopy]];
    }
  else if ([token isEqualToString:@"end"])
    {
      if ([_dictionaryStack count] > 1) [_dictionaryStack removeLastObject];
    }
  else if ([token isEqualToString:@"def"])
    {
      id value = [self pop];
      NSString *key = [self keyForName:[self pop]];
      ((NSMutableDictionary *)[_dictionaryStack lastObject])[key] = value ?: [NSNull null];
    }
  else if ([token isEqualToString:@"load"])
    {
      id value = [self lookupName:[self keyForName:[self pop]]];
      if (value != nil) [_operandStack addObject:value];
    }
  else if ([token isEqualToString:@"where"])
    {
      NSString *key = [self keyForName:[self pop]];
      for (NSDictionary *dict in [_dictionaryStack reverseObjectEnumerator])
        {
          if (dict[key] != nil)
            {
              [_operandStack addObject:dict];
              [_operandStack addObject:@YES];
              return;
            }
        }
      [_operandStack addObject:@NO];
    }
  else if ([token isEqualToString:@"known"])
    {
      NSString *key = [self keyForName:[self pop]];
      NSDictionary *dict = [self pop];
      [_operandStack addObject:@(dict[key] != nil)];
    }
  else if ([token isEqualToString:@"currentdict"])
    {
      [_operandStack addObject:[_dictionaryStack lastObject]];
    }
  else if ([token isEqualToString:@"type"])
    {
      id obj = [_operandStack lastObject];
      NSString *type = @"unknown";
      if ([obj isKindOfClass:[NSNumber class]]) type = @"numbertype";
      else if ([obj isKindOfClass:[NSString class]]) type = @"stringtype";
      else if ([obj isKindOfClass:[PSName class]]) type = @"nametype";
      else if ([obj isKindOfClass:[PSProcedure class]]) type = @"arraytype";
      else if ([obj isKindOfClass:[NSArray class]]) type = @"arraytype";
      else if ([obj isKindOfClass:[NSDictionary class]]) type = @"dicttype";
      [_operandStack addObject:[PSName nameWithString:type literal:YES]];
    }
  else if ([token isEqualToString:@"cvx"])
    {
      id obj = [self pop];
      if ([obj isKindOfClass:[NSArray class]])
        [_operandStack addObject:[PSProcedure procedureWithObjects:obj]];
      else if ([obj isKindOfClass:[PSName class]])
        {
          ((PSName *)obj).literal = NO;
          [_operandStack addObject:obj];
        }
      else
        [_operandStack addObject:obj];
    }
  else if ([token isEqualToString:@"cvlit"])
    {
      id obj = [self pop];
      if ([obj isKindOfClass:[PSProcedure class]])
        [_operandStack addObject:((PSProcedure *)obj).objects];
      else if ([obj isKindOfClass:[PSName class]])
        {
          ((PSName *)obj).literal = YES;
          [_operandStack addObject:obj];
        }
      else
        [_operandStack addObject:obj];
    }
  else if ([token isEqualToString:@"exec"])
    {
      id obj = [self pop];
      if ([obj isKindOfClass:[PSProcedure class]])
        [self executeObjects:((PSProcedure *)obj).objects];
      else
        [self executeObject:obj];
    }
  else if ([token isEqualToString:@"bind"] || [token isEqualToString:@"readonly"] ||
           [token isEqualToString:@"executeonly"] || [token isEqualToString:@"noaccess"])
    {
      /* Access attributes are not enforced; keep the operand usable. */
    }
  else if ([token isEqualToString:@"if"])
    {
      PSProcedure *procedure = [self pop];
      NSNumber *condition = [self popNumber];
      if ([condition boolValue] && [procedure isKindOfClass:[PSProcedure class]])
        [self executeObjects:procedure.objects];
    }
  else if ([token isEqualToString:@"ifelse"])
    {
      PSProcedure *elseProc = [self pop];
      PSProcedure *thenProc = [self pop];
      NSNumber *condition = [self popNumber];
      PSProcedure *procedure = [condition boolValue] ? thenProc : elseProc;
      if ([procedure isKindOfClass:[PSProcedure class]])
        [self executeObjects:procedure.objects];
    }
  else if ([token isEqualToString:@"repeat"])
    {
      PSProcedure *procedure = [self pop];
      NSInteger count = [[self popNumber] integerValue];
      for (NSInteger i = 0; i < count && !_exitFlag; i++)
        [self executeObjects:procedure.objects];
      _exitFlag = NO;
    }
  else if ([token isEqualToString:@"for"])
    {
      PSProcedure *procedure = [self pop];
      double increment = [[self popNumber] doubleValue];
      double limit = [[self popNumber] doubleValue];
      double start = [[self popNumber] doubleValue];
      for (double i = start; increment >= 0 ? i <= limit : i >= limit; i += increment)
        {
          [_operandStack addObject:@(i)];
          [self executeObjects:procedure.objects];
          if (_exitFlag) break;
        }
      _exitFlag = NO;
    }
  else if ([token isEqualToString:@"loop"])
    {
      PSProcedure *procedure = [self pop];
      while (!_exitFlag)
        [self executeObjects:procedure.objects];
      _exitFlag = NO;
    }
  else if ([token isEqualToString:@"exit"])
    {
      _exitFlag = YES;
    }
  else if ([token isEqualToString:@"save"])
    {
      NSDictionary *state = @{
        @"graphics": [_graphicsState copy],
        @"dicts": [[NSArray alloc] initWithArray:_dictionaryStack copyItems:YES]
      };
      [_operandStack addObject:state];
    }
  else if ([token isEqualToString:@"restore"])
    {
      NSDictionary *state = [self pop];
      _graphicsState = state[@"graphics"];
      _dictionaryStack = [state[@"dicts"] mutableCopy];
    }
  else if ([token isEqualToString:@"gsave"])
    {
      [_graphicsStack addObject:[_graphicsState copy]];
    }
  else if ([token isEqualToString:@"grestore"])
    {
      if ([_graphicsStack count] > 0)
        {
          _graphicsState = [_graphicsStack lastObject];
          [_graphicsStack removeLastObject];
        }
    }
  else if ([token isEqualToString:@"newpath"])
    {
      _graphicsState.path = [NSBezierPath bezierPath];
    }
  else if ([token isEqualToString:@"moveto"])
    {
      NSNumber *y = [self popNumber];
      NSNumber *x = [self popNumber];
      NSPoint point = [self transformPointX:x y:y];
      _graphicsState.currentPoint = point;
      [_graphicsState.path moveToPoint:point];
    }
  else if ([token isEqualToString:@"lineto"])
    {
      NSNumber *y = [self popNumber];
      NSNumber *x = [self popNumber];
      NSPoint point = [self transformPointX:x y:y];
      _graphicsState.currentPoint = point;
      [_graphicsState.path lineToPoint:point];
    }
  else if ([token isEqualToString:@"rmoveto"] || [token isEqualToString:@"rlineto"])
    {
      NSNumber *dy = [self popNumber];
      NSNumber *dx = [self popNumber];
      NSPoint point = NSMakePoint(_graphicsState.currentPoint.x + [dx doubleValue],
                                 _graphicsState.currentPoint.y + [dy doubleValue]);
      _graphicsState.currentPoint = point;
      if ([token isEqualToString:@"rmoveto"]) [_graphicsState.path moveToPoint:point];
      else [_graphicsState.path lineToPoint:point];
    }
  else if ([token isEqualToString:@"curveto"])
    {
      NSNumber *y3 = [self popNumber], *x3 = [self popNumber];
      NSNumber *y2 = [self popNumber], *x2 = [self popNumber];
      NSNumber *y1 = [self popNumber], *x1 = [self popNumber];
      NSPoint p1 = [self transformPointX:x1 y:y1];
      NSPoint p2 = [self transformPointX:x2 y:y2];
      NSPoint p3 = [self transformPointX:x3 y:y3];
      [_graphicsState.path curveToPoint:p3 controlPoint1:p1 controlPoint2:p2];
      _graphicsState.currentPoint = p3;
    }
  else if ([token isEqualToString:@"closepath"])
    {
      [_graphicsState.path closePath];
    }
  else if ([token isEqualToString:@"currentpoint"])
    {
      [_operandStack addObject:@(_graphicsState.currentPoint.x)];
      [_operandStack addObject:@(_graphicsState.currentPoint.y)];
    }
  else if ([token isEqualToString:@"arc"] || [token isEqualToString:@"arcn"])
    {
      NSNumber *a2 = [self popNumber], *a1 = [self popNumber], *r = [self popNumber];
      NSNumber *y = [self popNumber], *x = [self popNumber];
      NSPoint center = [self transformPointX:x y:y];
      [_graphicsState.path appendBezierPathWithArcWithCenter:center radius:[r doubleValue]
                                                  startAngle:[a1 doubleValue] endAngle:[a2 doubleValue]
                                                   clockwise:[token isEqualToString:@"arcn"]];
    }
  else if ([token isEqualToString:@"pathbbox"])
    {
      NSRect bounds = [_graphicsState.path bounds];
      [_operandStack addObject:@(NSMinX(bounds))];
      [_operandStack addObject:@(NSMinY(bounds))];
      [_operandStack addObject:@(NSMaxX(bounds))];
      [_operandStack addObject:@(NSMaxY(bounds))];
    }
  else if ([token isEqualToString:@"stroke"] || [token isEqualToString:@"fill"] || [token isEqualToString:@"eofill"])
    {
      [self addPaintOperation:token path:_graphicsState.path];
      _graphicsState.path = [NSBezierPath bezierPath];
    }
  else if ([token isEqualToString:@"rectfill"] || [token isEqualToString:@"rectstroke"])
    {
      NSNumber *h = [self popNumber], *w = [self popNumber], *y = [self popNumber], *x = [self popNumber];
      NSPoint origin = [self transformPointX:x y:y];
      PSRenderOperation *operation = [[PSRenderOperation alloc] init];
      operation.type = token;
      operation.rect = NSMakeRect(origin.x, origin.y, [w doubleValue], [h doubleValue]);
      operation.strokeColor = _graphicsState.strokeColor;
      operation.fillColor = _graphicsState.fillColor;
      operation.lineWidth = _graphicsState.lineWidth;
      operation.clipPath = [_graphicsState.clipPath copy];
      [_renderOperations addObject:operation];
    }
  else if ([token isEqualToString:@"setlinewidth"])
    {
      _graphicsState.lineWidth = [[self popNumber] doubleValue];
    }
  else if ([token isEqualToString:@"setgray"])
    {
      CGFloat g = [[self popNumber] doubleValue];
      NSColor *color = [NSColor colorWithCalibratedWhite:g alpha:1.0];
      _graphicsState.strokeColor = color;
      _graphicsState.fillColor = color;
    }
  else if ([token isEqualToString:@"setrgbcolor"])
    {
      CGFloat b = [[self popNumber] doubleValue];
      CGFloat g = [[self popNumber] doubleValue];
      CGFloat r = [[self popNumber] doubleValue];
      NSColor *color = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
      _graphicsState.strokeColor = color;
      _graphicsState.fillColor = color;
    }
  else if ([token isEqualToString:@"clip"] || [token isEqualToString:@"eoclip"])
    {
      _graphicsState.clipPath = [_graphicsState.path copy];
      if ([token isEqualToString:@"eoclip"]) [_graphicsState.clipPath setWindingRule:NSEvenOddWindingRule];
    }
  else if ([token isEqualToString:@"initclip"])
    {
      _graphicsState.clipPath = nil;
    }
  else if ([token isEqualToString:@"translate"])
    {
      NSNumber *ty = [self popNumber], *tx = [self popNumber];
      [_graphicsState.transform translateXBy:[tx doubleValue] yBy:[ty doubleValue]];
    }
  else if ([token isEqualToString:@"scale"])
    {
      NSNumber *sy = [self popNumber], *sx = [self popNumber];
      [_graphicsState.transform scaleXBy:[sx doubleValue] yBy:[sy doubleValue]];
    }
  else if ([token isEqualToString:@"rotate"])
    {
      [_graphicsState.transform rotateByDegrees:[[self popNumber] doubleValue]];
    }
  else if ([token isEqualToString:@"currentmatrix"])
    {
      id matrix = [_operandStack count] > 0 ? [self pop] : nil;
      NSMutableArray *values = [self matrixArrayFromTransform:_graphicsState.transform];
      if ([matrix isKindOfClass:[NSMutableArray class]] && [matrix count] >= 6)
        {
          for (NSUInteger i = 0; i < 6; i++) matrix[i] = values[i];
          [_operandStack addObject:matrix];
        }
      else
        {
          [_operandStack addObject:values];
        }
    }
  else if ([token isEqualToString:@"setmatrix"])
    {
      NSAffineTransform *matrix = [self transformFromMatrixObject:[self pop]];
      if (matrix != nil) _graphicsState.transform = matrix;
    }
  else if ([token isEqualToString:@"initmatrix"])
    {
      _graphicsState.transform = [NSAffineTransform transform];
    }
  else if ([token isEqualToString:@"matrix"])
    {
      [_operandStack addObject:[NSMutableArray arrayWithObjects:@1, @0, @0, @1, @0, @0, nil]];
    }
  else if ([token isEqualToString:@"identmatrix"])
    {
      id matrix = [_operandStack count] > 0 ? [self pop] : nil;
      NSMutableArray *identity = [NSMutableArray arrayWithObjects:@1, @0, @0, @1, @0, @0, nil];
      if ([matrix isKindOfClass:[NSMutableArray class]] && [matrix count] >= 6)
        {
          for (NSUInteger i = 0; i < 6; i++) matrix[i] = identity[i];
          [_operandStack addObject:matrix];
        }
      else
        {
          [_operandStack addObject:identity];
        }
    }
  else if ([token isEqualToString:@"defaultmatrix"])
    {
      id matrix = [_operandStack count] > 0 ? [self pop] : nil;
      NSMutableArray *identity = [NSMutableArray arrayWithObjects:@1, @0, @0, @1, @0, @0, nil];
      if ([matrix isKindOfClass:[NSMutableArray class]] && [matrix count] >= 6)
        {
          for (NSUInteger i = 0; i < 6; i++) matrix[i] = identity[i];
          [_operandStack addObject:matrix];
        }
      else
        {
          [_operandStack addObject:identity];
        }
    }
  else if ([token isEqualToString:@"findfont"])
    {
      id fontName = [self pop];
      [_operandStack addObject:[self fontFromObject:fontName size:12.0]];
    }
  else if ([token isEqualToString:@"scalefont"])
    {
      CGFloat size = [[self popNumber] doubleValue];
      id font = [self pop];
      [_operandStack addObject:[self fontFromObject:font size:size]];
    }
  else if ([token isEqualToString:@"setfont"])
    {
      id font = [self pop];
      if ([font isKindOfClass:[NSFont class]]) _graphicsState.font = font;
      else _graphicsState.font = [self fontFromObject:font size:12.0];
    }
  else if ([token isEqualToString:@"currentfont"])
    {
      [_operandStack addObject:_graphicsState.font];
    }
  else if ([token isEqualToString:@"show"])
    {
      NSString *text = [[self pop] description];
      PSRenderOperation *operation = [[PSRenderOperation alloc] init];
      operation.type = @"show";
      operation.text = text;
      operation.point = _graphicsState.currentPoint;
      operation.font = _graphicsState.font;
      operation.strokeColor = _graphicsState.strokeColor;
      operation.clipPath = [_graphicsState.clipPath copy];
      [_renderOperations addObject:operation];
      NSSize size = [text sizeWithAttributes:@{ NSFontAttributeName: _graphicsState.font }];
      _graphicsState.currentPoint = NSMakePoint(_graphicsState.currentPoint.x + size.width, _graphicsState.currentPoint.y);
    }
  else if ([token isEqualToString:@"image"] || [token isEqualToString:@"imagegray"] || [token isEqualToString:@"imagemask"])
    {
      NSData *data = [self pop];
      NSNumber *height = [self popNumber];
      NSNumber *width = [self popNumber];
      NSInteger pixelsWide = MAX([width integerValue], 1);
      NSInteger pixelsHigh = MAX([height integerValue], 1);
      NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:pixelsWide pixelsHigh:pixelsHigh
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:pixelsWide * 4 bitsPerPixel:32];
      unsigned char *rgba = [bitmap bitmapData];
      const unsigned char *bytes = [data bytes];
      NSUInteger length = [data length];
      for (NSInteger i = 0; i < pixelsWide * pixelsHigh; i++)
        {
          unsigned char v = i < (NSInteger)length ? bytes[i] : 0;
          rgba[i * 4 + 0] = [token isEqualToString:@"imagemask"] ? 0 : v;
          rgba[i * 4 + 1] = [token isEqualToString:@"imagemask"] ? 0 : v;
          rgba[i * 4 + 2] = [token isEqualToString:@"imagemask"] ? 0 : v;
          rgba[i * 4 + 3] = [token isEqualToString:@"imagegray"] ? 255 : v;
        }
      NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(pixelsWide, pixelsHigh)];
      [image addRepresentation:bitmap];
      PSRenderOperation *operation = [[PSRenderOperation alloc] init];
      operation.type = @"image";
      operation.image = image;
      operation.point = _graphicsState.currentPoint;
      operation.clipPath = [_graphicsState.clipPath copy];
      [_renderOperations addObject:operation];
    }
  else if ([token isEqualToString:@"showpage"])
    {
      [_renderView setNeedsDisplay:YES];
    }
  else
    {
      [_operandStack addObject:[PSName nameWithString:token literal:NO]];
    }
}
@end
