/* Copyright (C) 2009-2011 Mikkel Krautz <mikkel@krautz.dk>

   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   - Neither the name of the Mumble Developers nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "MUServerCell.h"
#import "MUFavouriteServer.h"

@interface MUServerCell () {
    NSString        *_displayname;
    NSString        *_hostname;
    NSString        *_port;
    NSString        *_username;
    MKServerPinger  *_pinger;
}
- (UIImage *) drawPingImageWithPingValue:(NSUInteger)pingMs andSize:(CGSize)sz;
@end

@implementation MUServerCell

+ (NSString *) reuseIdentifier {
    return @"ServerCell";
}

- (id) init {
    return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:[MUServerCell reuseIdentifier]];
}

- (void) dealloc {    
    [_hostname release];
    [_port release];
    [_username release];
    [_displayname release];
    [_pinger release];
    [super dealloc];
}

- (void) populateFromDisplayName:(NSString *)displayName hostName:(NSString *)hostName port:(NSString *)port {
    [_displayname release];
    _displayname = [displayName copy];

    [_hostname release];
    _hostname = [hostName copy];

    [_port release];
    _port = [port copy];

    [_pinger release];
    _pinger = [[MKServerPinger alloc] initWithHostname:_hostname port:_port];
    [_pinger setDelegate:self];

    self.textLabel.text = _displayname;
    self.detailTextLabel.text = [NSString stringWithFormat:@"%@:%@", _hostname, _port];
    self.imageView.image = [self drawPingImageWithPingValue:999 andSize:CGSizeMake(32.0, 32.0)];
}

- (void) populateFromFavouriteServer:(MUFavouriteServer *)favServ {
    [_displayname release];
    _displayname = [[favServ displayName] copy];

    [_hostname release];
    _hostname = [[favServ hostName] copy];

    [_port release];
    _port = [[NSString stringWithFormat:@"%u", [favServ port]] retain];

    [_username release];
    if ([[favServ userName] length] > 0) {
        _username = [[favServ userName] copy];
    } else {
        _username = @"MumbleUser";
    }

    [_pinger release];
    _pinger = nil;
    if ([_hostname length] > 0) {
        _pinger = [[MKServerPinger alloc] initWithHostname:_hostname port:_port];
        [_pinger setDelegate:self];
    } else {
        _hostname = @"(No Server)";
    }

    self.textLabel.text = _displayname;
    self.detailTextLabel.text = [NSString stringWithFormat:@"%@ on %@:%@", _username, _hostname, _port];
    self.imageView.image = [self drawPingImageWithPingValue:999 andSize:CGSizeMake(32.0, 32.0)];
}

- (void) setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (UIImage *) drawPingImageWithPingValue:(NSUInteger)pingMs andSize:(CGSize)sz {
    UIImage *img = nil;

    // #609a4b
    UIColor *goodPing = [UIColor colorWithRed:0x60/255.0f green:0x9a/255.0f blue:0x4b/255.0f alpha:1.0f];
    // #F2DE69
    UIColor *mediumPing = [UIColor colorWithRed:0xf2/255.0f green:0xde/255.0f blue:0x69/255.0f alpha:1.0f];
    // #D14D54
    UIColor *badPing = [UIColor colorWithRed:0xd1/255.0f green:0x4d/255.0f blue:0x54/255.0f alpha:1.0f];
    
    UIColor *pingColor = badPing;
    if (pingMs <= 125)
        pingColor = goodPing;
    else if (pingMs > 125 && pingMs <= 250)
        pingColor = mediumPing;
    else if (pingMs > 250)
        pingColor = badPing;
    NSString *pingStr = [NSString stringWithFormat:@"%u ms", pingMs];
    if (pingMs >= 999)
        pingStr = @"999+ ms";

    UIGraphicsBeginImageContext(sz);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, pingColor.CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, sz.width, sz.height));
    
    CGContextSetTextDrawingMode(ctx, kCGTextFill);
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    
    [pingStr drawInRect:CGRectMake(0, 0, sz.width, sz.height)
               withFont:[UIFont systemFontOfSize:12]
          lineBreakMode:UILineBreakModeTailTruncation
              alignment:UITextAlignmentCenter];
    
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return img;
}

- (void) serverPingerResult:(MKServerPingerResult *)result {
    NSUInteger pingValue = (NSUInteger)(result->ping * 1000.0f);
    self.imageView.image = [self drawPingImageWithPingValue:pingValue andSize:CGSizeMake(32.0, 32.0)];
}

@end
