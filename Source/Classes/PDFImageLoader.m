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

#import "PDFImageLoader.h"

static PDFImageLoader *pdfLoaderState = nil;

@implementation PDFImageLoader

- (id) init {
	self = [super init];
	if (self == nil)
		return nil;

	files = [[NSMutableDictionary alloc] init];

	return self;
}

- (void) dealloc {
	[super dealloc];
	[files release];
}

- (UIImage *) imageFromPDF:(NSString *)filename {
	UIImage *image = [files objectForKey:filename];
	if (image) {
		return image;
	}

	UIGraphicsBeginImageContext(CGSizeMake(32, 32));
	CGContextRef context = UIGraphicsGetCurrentContext();

	NSString *pdfPath = [[NSBundle mainBundle] pathForResource:filename ofType:@"pdf"];
	NSURL *pdfUrl = [NSURL fileURLWithPath:pdfPath];

	CGPDFDocumentRef pdfDocument = CGPDFDocumentCreateWithURL((CFURLRef)pdfUrl);
	CGPDFPageRef pdfPage = CGPDFDocumentGetPage(pdfDocument, 1);

	CGContextTranslateCTM(context, 0.0, 32.0);
	CGContextScaleCTM(context, 1.0, -1.0);

	CGContextSaveGState(context);
	CGAffineTransform pdfTransform = CGPDFPageGetDrawingTransform(pdfPage, kCGPDFCropBox, CGRectMake(0, 0, 32, 32), 0, YES);
	CGContextConcatCTM(context, pdfTransform);
	CGContextDrawPDFPage(context, pdfPage);
	CGContextRestoreGState(context);

	CGPDFDocumentRelease(pdfDocument);

	image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	[files setObject:image forKey:filename];
	NSLog(@"PDFImageLoader: Image '%@' now cached.", filename);

	return image;
}

+ (UIImage *) imageFromPDF:(NSString *)filename {
	if (pdfLoaderState == nil) {
		NSLog(@"PDFImageLoader: Allocating new PDFLoader state.");
		pdfLoaderState = [[PDFImageLoader alloc] init];
	}
	return [pdfLoaderState imageFromPDF:filename];
}

@end
