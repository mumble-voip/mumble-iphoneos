/* Copyright (C) 2009-2010 Mikkel Krautz <mikkel@krautz.dk>

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

#import "AvatarCell.h"

@implementation AvatarCell

- (void) dealloc {
	[_avatarImage release];
	[super dealloc];
}

+ (AvatarCell *) loadFromNib {
	NSArray *array = [[NSBundle mainBundle] loadNibNamed:@"AvatarCell" owner:self options:nil];
	return [array objectAtIndex:0];
}

- (void) setAvatarImage:(UIImage *)image {
	_avatarImage = [UIImage imageWithCGImage:[image CGImage]];
	[_avatarImageView setImage:_avatarImage];

	[[_avatarImageView layer] setBackgroundColor:[[UIColor whiteColor] CGColor]];
	[[_avatarImageView layer] setMasksToBounds:YES];
	[[_avatarImageView layer] setCornerRadius:10.0f];
	[[_avatarImageView layer] setBorderWidth:1.0f];
	[[_avatarImageView layer] setBorderColor:[[UIColor colorWithRed:0.298 green:0.337 blue:0.424 alpha:1.0] CGColor]];
	
	[[_avatarImageView layer] setShadowColor:[[UIColor whiteColor] CGColor]];
	[[_avatarImageView layer] setShadowOffset:CGSizeMake(-1.0f, 1.0f)];
	[[_avatarImageView layer] setShadowOpacity:1.0f];
	[[_avatarImageView layer] setShadowRadius:1.0f];
}

- (void) setSelected:(BOOL)selected animated:(BOOL)animated {
	[self setHighlighted:selected animated:animated];
}

- (void) setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
	if (highlighted) {
		[[_avatarImageView layer] setOpacity:0.5f];
	} else {
		[[_avatarImageView layer] setOpacity:1.0f];
	}
}

@end
