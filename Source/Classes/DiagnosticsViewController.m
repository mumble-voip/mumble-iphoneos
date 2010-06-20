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

#import <MumbleKit/MKAudio.h>

#include <sys/types.h>
#include <sys/sysctl.h>

#import "DiagnosticsViewController.h"

@interface DiagnosticsViewController (Private)
- (void) updateDiagnostics:(NSTimer *)timer;

- (NSString *) deviceString;

- (void) submitButtonClicked:(UIBarButtonItem *)submitButton;

- (void) setSubmitButton;
- (void) setActivityIndicator;

- (NSData *) formEncodedDictionary:(NSDictionary *)dict boundary:(NSString *)boundary;
- (void) submitDiagnostics;
@end

@implementation DiagnosticsViewController

#pragma mark -
#pragma mark Initialization

- (id) init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self == nil)
		return nil;

	UIDevice *device = [UIDevice currentDevice];

	// System
	_deviceCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DiagnosticsCell"];
	[_deviceCell setSelectionStyle:UITableViewCellSelectionStyleNone];
	[[_deviceCell textLabel] setText:@"Device"];
	[[_deviceCell detailTextLabel] setText:[self deviceString]];
	[[_deviceCell detailTextLabel] setAdjustsFontSizeToFitWidth:YES];

	_osCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DiagnosticsCell"];
	[_osCell setSelectionStyle:UITableViewCellSelectionStyleNone];
	[[_osCell textLabel] setText:@"System"];
	[[_osCell detailTextLabel] setText:[NSString stringWithFormat:@"%@ %@", [device systemName], [device systemVersion]]];
	[[_osCell detailTextLabel] setAdjustsFontSizeToFitWidth:YES];

	_udidCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DiagnosticsCell"];
	[_udidCell setSelectionStyle:UITableViewCellSelectionStyleNone];
	[[_udidCell textLabel] setText:@"UDID"];
	[[_udidCell detailTextLabel] setText:[device uniqueIdentifier]];
	[[_udidCell detailTextLabel] setAdjustsFontSizeToFitWidth:YES];

	// Build
	_versionCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DiagnosticsCell"];
	[_versionCell setSelectionStyle:UITableViewCellSelectionStyleNone];
	[[_versionCell textLabel] setText:@"Version"];
	[[_versionCell detailTextLabel] setText:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];

	_gitRevCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DiagnosticsCell"];
	[_gitRevCell setSelectionStyle:UITableViewCellSelectionStyleNone];
	[[_gitRevCell textLabel] setText:@"Git Revision"];
	[[_gitRevCell detailTextLabel] setText:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"MumbleGitRevision"]];

	_buildDateCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DiagnosticsCell"];
	[_buildDateCell setSelectionStyle:UITableViewCellSelectionStyleNone];
	[[_buildDateCell textLabel] setText:@"Build Date"];
	[[_buildDateCell detailTextLabel] setText:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"MumbleBuildDate"]];
	[[_buildDateCell detailTextLabel] setAdjustsFontSizeToFitWidth:YES];

	// Audio
	_preprocessorCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DiagnosticsCell"];
	[_preprocessorCell setSelectionStyle:UITableViewCellSelectionStyleNone];
	[[_preprocessorCell textLabel] setText:@"Preprocessor"];
	[[_preprocessorCell detailTextLabel] setText:@"∞ µs"];
	[[_preprocessorCell detailTextLabel] setAdjustsFontSizeToFitWidth:YES];

	_updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateDiagnostics:) userInfo:nil repeats:YES];
	[self updateDiagnostics:nil];
	
	return self;
}

- (void) dealloc {
	[_updateTimer invalidate];

	[_deviceCell release];
	[_osCell release];
	[_udidCell release];

	[_versionCell release];
	[_gitRevCell release];
	[_buildDateCell release];

	[_preprocessorCell release];

	[super dealloc];
}

#pragma mark -
#pragma mark View lifecycle

- (void) viewWillAppear:(BOOL)animated {
	[[self navigationItem] setTitle:@"Diagnostics"];
	[self setSubmitButton];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) // System
		return 3;
	if (section == 1) // Build
		return 3;
	if (section == 2) // Audio
		return 1;
	return 0;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return @"System";
	if (section == 1)
		return @"Build";
	if (section == 2)
		return @"Audio";
	return @"Default";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([indexPath section] == 0) { // System
		if ([indexPath row] == 0) { // Device
			return _deviceCell;
		} else if ([indexPath row] == 1) { // OS
			return _osCell;
		} else if ([indexPath row] == 2) { // UDID
			return _udidCell;
		}
	} else if ([indexPath section] == 1) { // Build
		if ([indexPath row] == 0) { // Version
			return _versionCell;
		} else if ([indexPath row] == 1) { // Git Revision
			return _gitRevCell;
		} else if ([indexPath row] == 2) { // Build Date
			return _buildDateCell;
		}
	} else if ([indexPath section] == 2) { // Audio
		if ([indexPath row] == 0) { // Preprocessor
			return _preprocessorCell;
		}
	}
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark -
#pragma mark Device query

- (NSString *) deviceString {
	NSString *devString = nil;
	char *devName = NULL;
	size_t size = 0;

	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	devName = malloc(size);
	sysctlbyname("hw.machine", devName, &size, NULL, 0);
	devString = [NSString stringWithUTF8String:devName];
	free(devName);

	return devString;
}

#pragma mark -
#pragma mark Helpers

- (void) setSubmitButton {
	// Submit button
	UIBarButtonItem *submitButton = [[UIBarButtonItem alloc] initWithTitle:@"Submit" style:UIBarButtonItemStyleDone target:self action:@selector(submitButtonClicked:)];
	[[self navigationItem] setRightBarButtonItem:submitButton];
	[submitButton release];
}

- (void) setActivityIndicator {
	// Swap submit button for activity indicator
	UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	[activity startAnimating];
	UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithCustomView:activity];
	[[self navigationItem] setRightBarButtonItem:rightButton];
	[rightButton release];
	[activity release];
}

- (void) updateDiagnostics:(NSTimer *)timer {
	MKAudio *audio = [MKAudio sharedAudio];

	MKAudioBenchmark data;
	[audio getBenchmarkData:&data];

	[[_preprocessorCell detailTextLabel] setText:[NSString stringWithFormat:@"%li µs", data.avgPreprocessorRuntime]];
}

- (NSData *) formEncodedDictionary:(NSDictionary *)dict boundary:(NSString *)boundary {
	NSMutableData *data = [[NSMutableData alloc] init];

	[dict enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		[data appendData:[[NSString stringWithFormat:@"\r\n\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", (NSString *)key] dataUsingEncoding:NSUTF8StringEncoding]];
		[data appendData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding]];
	}];
	[data appendData:[[NSString stringWithFormat:@"\r\n\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

	return [data autorelease];
}

- (void) submitDiagnostics {
	static NSString *boundary = @"DFfsafwEFQFQWEfq";

	MKAudioBenchmark bench;
	[[MKAudio sharedAudio] getBenchmarkData:&bench];
	UIDevice *device = [UIDevice currentDevice];

	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	// System
	[dict setObject:[self deviceString] forKey:@"device"];
	[dict setObject:[NSString stringWithFormat:@"%@ %@", [device systemName], [device systemVersion]] forKey:@"operating-system"];
	[dict setObject:[device uniqueIdentifier] forKey:@"udid"];
	// Build
	[dict setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:@"version"];
	[dict setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"MumbleGitRevision"] forKey:@"git-revision"];
	[dict setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"MumbleBuildDate"] forKey:@"build-date"];
	// Audio
	[dict setObject:[NSString stringWithFormat:@"%li", bench.avgPreprocessorRuntime] forKey:@"preprocessor-avg-runtime"];

	NSURL *url = [NSURL URLWithString:@"https://mumble-iphoneos.appspot.com/diagnostics"];
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0f];
	[req setHTTPMethod:@"POST"];
	[req setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
	[req setHTTPBody:[self formEncodedDictionary:dict boundary:boundary]];
	[NSURLConnection connectionWithRequest:req delegate:self];

	[dict release];
}

#pragma mark -
#pragma mark NSURLConnection delegate

- (void) connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {												
	[self setSubmitButton];
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[self setSubmitButton];
}

#pragma mark -
#pragma mark Target/actions

- (void) submitButtonClicked:(UIBarButtonItem *)submitButton {
	[self setActivityIndicator];
	[self submitDiagnostics];
}

@end