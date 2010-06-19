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

#import "TableViewTextFieldCell.h"

@implementation TableViewTextFieldCell

- (id) initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (self == nil)
		return nil;

	[self setSelectionStyle:UITableViewCellSelectionStyleNone];

	UIView *view = self.contentView;

	_label = [[UILabel alloc] init];
	[_label setText:@"DefaultLabelText"];
	[_label setFont:[UIFont boldSystemFontOfSize:16.0f]];
	[view addSubview:_label];
	[_label setOpaque:NO];
	[_label setBackgroundColor:[UIColor clearColor]];
	[_label release];

	_textField = [[UITextField alloc] init];
	[_textField setFont:[UIFont systemFontOfSize:14.0f]];
	[_textField setTextColor:[UIColor colorWithRed:(CGFloat)0x32/0xff green:(CGFloat)0x4f/0xff blue:(CGFloat)0x85/0xff alpha:0xff]];
	[_textField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
	[_textField setDelegate:self];
	[view addSubview:_textField];
	[_textField release];

    return self;
}

- (void) dealloc {
    [super dealloc];
}

- (void) setSelected:(BOOL)selected animated:(BOOL)animated {
	// Should not be able to select these.
}

#pragma mark -
#pragma mark Action helper

- (void) performValueChangedSelector {
	id targ = [self target];
	if ([targ respondsToSelector:_valueChangedAction])
		[[NSRunLoop currentRunLoop] performSelector:_valueChangedAction target:targ argument:self order:0 modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
	else
		NSLog(@"TableViewTextFieldCell: Target does not respond to given selector.");
}

#pragma mark -
#pragma mark Layout

- (void) layoutSubviews {
	[super layoutSubviews];

	CGRect contentBounds = [[self contentView] bounds];
	CGFloat x = contentBounds.origin.x;
	CGFloat y = contentBounds.origin.y;
	CGFloat w = contentBounds.size.width;
	CGFloat h = contentBounds.size.height;

	CGFloat labelWidth = (3*w)/8;
	CGFloat textFieldWidth = (5*w)/8;

	x += 8.0f;
	labelWidth -= 8.0f;
	CGRect labelFrame = CGRectIntegral(CGRectMake(x, y, labelWidth, h));

	x += labelWidth;
	textFieldWidth -= 8.0f;
	CGRect textFieldFrame = CGRectIntegral(CGRectMake(x, y, textFieldWidth, h));

	[_label setFrame:labelFrame];
	[_textField setFrame:textFieldFrame];
}

#pragma mark -
#pragma mark Accessors

- (void) setLabel:(NSString *)labelText {
	[_label setText:labelText];
}

- (NSString *) label {
	return [_label text];
}

- (void) setPlaceholder:(NSString *)defaultValue {
	[_textField setPlaceholder:defaultValue];
}

- (NSString *) placeholder {
	return [_textField placeholder];
}

- (void) setTextValue:(NSString *)val {
	if ([val length] == 0)
		val = nil;
	[_textField setText:val];
	[self performValueChangedSelector];
}

- (NSString *) textValue {
	NSString *value = [[_textField text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([value length] == 0) {
		return nil;
	}
	return value;
}

- (void) setIntValue:(int)val {
	[_textField setText:[NSString stringWithFormat:@"%i", val]];
	[self performValueChangedSelector];
}

- (int) intValue {
	return [[_textField text] intValue];
}

- (void) setValueChangedAction:(SEL)selector {
	_valueChangedAction = selector;
}

- (SEL) valueChangedAction {
	return _valueChangedAction;
}

#pragma mark -
#pragma mark UITextFieldDelegate

- (void) textFieldDidEndEditing:(UITextField *)textField {
	[self performValueChangedSelector];
}

- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	[self performValueChangedSelector];
	return YES;
}

#pragma mark -
#pragma mark UITextInptTraits protocol

- (UITextAutocapitalizationType) autocapitalizationType {
	return [_textField autocapitalizationType];
}

- (void) setAutocapitalizationType:(UITextAutocapitalizationType)autoCap {
	[_textField setAutocapitalizationType:autoCap];
}

- (UITextAutocorrectionType) autocorrectionType {
	return [_textField autocorrectionType];
}

- (void) setAutocorrectionType:(UITextAutocorrectionType)autoCorrection {
	[_textField setAutocorrectionType:autoCorrection];
}

- (BOOL) enablesReturnKeyAutomatically {
	return [_textField enablesReturnKeyAutomatically];
}

- (void) setEnablesReturnKeyAutomatically:(BOOL)enableKey {
	[_textField setEnablesReturnKeyAutomatically:enableKey];
}

- (UIKeyboardAppearance) keyboardAppearance {
	return [_textField keyboardAppearance];
}

- (void) setKeyboardAppearance:(UIKeyboardAppearance)appearance {
	[_textField setKeyboardAppearance:appearance];
}

- (UIKeyboardType) keyboardType {
	return [_textField keyboardType];
}

- (void) setKeyboardType:(UIKeyboardType)type {
	[_textField setKeyboardType:type];
}

- (UIReturnKeyType) returnKeyType {
	return [_textField returnKeyType];
}

- (void) setReturnKeyType:(UIReturnKeyType)type {
	[_textField setReturnKeyType:type];
}

- (BOOL) secureTextEntry {
	return [_textField isSecureTextEntry];
}

- (void) setSecureTextEntry:(BOOL)flag {
	[_textField setSecureTextEntry:flag];
}

@end
