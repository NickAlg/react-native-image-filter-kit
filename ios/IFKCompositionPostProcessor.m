#import "IFKInputConverter.h"
#import "IFKCompositionPostProcessor.h"
#import "NSArray+FilterMapReduce.h"

@interface IFKPostProcessor ()

- (nonnull UIImage *)filteredImageWithScale:(CGFloat)scale
                                 resizeMode:(RCTResizeMode)resizeMode
                                  viewFrame:(CGRect)viewFrame
                                   destSize:(CGSize)destSize;
- (nonnull CIFilter *)filter;
- (void)initFilter:(CGSize)size;
- (nonnull NSDictionary*)inputs;

@end

@interface IFKCompositionPostProcessor ()

@property (nonatomic, strong) IFKScale *dstScale;
@property (nonatomic, assign) CGPoint dstAnchor;
@property (nonatomic, assign) CGPoint dstPosition;
@property (nonatomic, assign) CGFloat dstRotate;
@property (nonatomic, strong) IFKScale *srcScale;
@property (nonatomic, assign) CGPoint srcAnchor;
@property (nonatomic, assign) CGPoint srcPosition;
@property (nonatomic, assign) CGFloat srcRotate;
@property (nonatomic, assign) BOOL swapImages;
@property (nonatomic, assign) CGSize canvasSize;
@property (nonatomic, strong) NSString *resizeCanvasTo;

@end

@implementation IFKCompositionPostProcessor

- (nonnull instancetype)initWithName:(nonnull NSString *)name
                              inputs:(nonnull NSDictionary *)inputs
                          canvasSize:(CGSize)canvasSize
{
  if ((self = [super initWithName:name inputs:inputs])) {
    CIVector *center = [CIVector vectorWithCGPoint:CGPointMake(0.5f, 0.5f)];
    CGPoint noScale =CGPointMake(1.0f, 1.0f);
    
    NSLog(@"IFK inputs %@", inputs);

    _dstScale = [IFKInputConverter convertScale:[[self inputs] objectForKey:@"dstScale"]
                                    defaultMode:COVER
                                   defaultScale:noScale];
    _srcScale = [IFKInputConverter convertScale:[[self inputs] objectForKey:@"srcScale"]
                                    defaultMode:COVER
                                   defaultScale:noScale];
    _dstAnchor = [[IFKInputConverter convertOffset:[[self inputs] objectForKey:@"dstAnchor"]
                                      defaultValue:center] CGPointValue];
    _srcAnchor = [[IFKInputConverter convertOffset:[[self inputs] objectForKey:@"srcAnchor"]
                                      defaultValue:center] CGPointValue];
    _dstRotate = [[IFKInputConverter convertAngle:[[self inputs] objectForKey:@"dstRotate"]
                                      defaultValue:@(0)] floatValue];
    _srcRotate = [[IFKInputConverter convertAngle:[[self inputs] objectForKey:@"srcRotate"]
                                      defaultValue:@(0)] floatValue];
    _dstPosition = [[IFKInputConverter convertOffset:[[self inputs] objectForKey:@"dstPosition"]
                                        defaultValue:center] CGPointValue];
    _srcPosition = [[IFKInputConverter convertOffset:[[self inputs] objectForKey:@"srcPosition"]
                                        defaultValue:center] CGPointValue];
    _swapImages = [[IFKInputConverter convertBoolean:[[self inputs] objectForKey:@"swapImages"]
                                        defaultValue:@(NO)] boolValue];
    _resizeCanvasTo = [IFKInputConverter convertText:[[self inputs] objectForKey:@"resizeCanvasTo"]
                                        defaultValue:nil];
    _canvasSize = canvasSize;
  }
  
  return self;
}

+ (CGAffineTransform)imageTransformWithCanvasWidth:(CGFloat)canvasWidth
                                      canvasHeight:(CGFloat)canvasHeight
                                        imageWidth:(CGFloat)bitmapWidth
                                       imageHeight:(CGFloat)bitmapHeight
                                        scale:(nonnull IFKScale *)scale
                                            anchor:(CGPoint)anchor
                                          position:(CGPoint)position
                                            rotate:(CGFloat)rotate
{
  CGFloat width = 0;
  CGFloat height = 0;
  
  if ([scale isKindOfClass:[IFKScaleWithMode class]]) {
    IFKScaleMode mode = ((IFKScaleWithMode *)scale).mode;
    CGFloat bitmapAspect = bitmapWidth / bitmapHeight;
    CGFloat canvasAspect = canvasWidth / canvasHeight;
    
    if (mode == CONTAIN) {
      if (bitmapAspect < canvasAspect) {
        height = canvasHeight;
        width = bitmapWidth * height / bitmapHeight;
      } else {
        width = canvasWidth;
        height = bitmapHeight * width / bitmapWidth;
      }
      
    } else if (mode == COVER) {
      if (bitmapAspect < canvasAspect) {
        width = canvasWidth;
        height = bitmapHeight * width / bitmapWidth;
      } else {
        height = canvasHeight;
        width = bitmapWidth * height / bitmapHeight;
      }
      
    } else if (mode == STRETCH) {
      width = canvasWidth;
      height = canvasHeight;
    }
    
  } else if ([scale isKindOfClass:[IFKScaleWithSize class]]) {
    width = canvasWidth * ((IFKScaleWithSize *) scale).scale.x;
    height = canvasHeight * ((IFKScaleWithSize *) scale).scale.y;
  }
  
  CGRect frame = CGRectMake(canvasWidth * position.x - width * anchor.x,
                            canvasHeight * position.y - height * anchor.y,
                            width,
                            height);
  
  CGAffineTransform transform = CGAffineTransformMakeScale(frame.size.width / bitmapWidth, frame.size.height / bitmapHeight);
  transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(-frame.size.width / 2.0f, -frame.size.height / 2.0f));
  transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(-rotate));
  transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(frame.size.width / 2.0f, frame.size.height / 2.0f));
  transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(frame.origin.x, frame.origin.y));
  
  return transform;
}

- (nonnull NSString *)dstImageName
{
  static NSArray<NSString *> *dstImageNames;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    dstImageNames = @[
      @"inputBackgroundImage",
      @"inputMask",
      @"inputGradientImage",
      @"inputTargetImage",
      @"inputDisplacementImage",
      @"inputTexture",
      @"inputShadingImage"
    ];
  });
  
  NSArray *inputKeys = [[self filter] inputKeys];
  
  NSString *name = [dstImageNames reduce:^id(id acc, NSString *val, int idx) {
    return [inputKeys containsObject:val] ? val : acc;
  } init:@""];
  
  RCTAssert(![name isEqualToString:@""],
            @"ImageFilterKit: unknown filter input - %@",
            [self filter].name);
  
  return name;
}

- (CGFloat)canvasExtentWithDstExtent:(CGFloat)dstExtent
                           srcExtent:(CGFloat)srcExtent
                       defaultExtent:(CGFloat)defaultExtent
{
  if (_resizeCanvasTo == nil) {
    return defaultExtent;
  }
  
  if ([@"dstImage" isEqualToString:_resizeCanvasTo]) {
    return dstExtent;
  }
  
  if ([@"srcImage" isEqualToString:_resizeCanvasTo]) {
    return srcExtent;
  }
  
  if ([@"MIN" isEqualToString:_resizeCanvasTo]) {
    return MIN(dstExtent, srcExtent);
  }
  
  if ([@"MAX" isEqualToString:_resizeCanvasTo]) {
    return MAX(dstExtent, srcExtent);
  }
  
  RCTAssert(false, @"ImageFilterKit: unknown resizeCanvasTo input - %@", _resizeCanvasTo);
  
  return 0;
}

- (nonnull UIImage *)processFilter:(nonnull UIImage *)image resizeMode:(RCTResizeMode)resizeMode
{
  CIImage *srcImage = [[CIImage alloc] initWithImage:image];
  CIImage *dstImage = ((CIImage *)[self inputs][[self dstImageName]][@"image"]);
  CGRect srcFrame = srcImage.extent;
  CGRect dstFrame = dstImage.extent;
  
  CGSize outSize = CGSizeMake(
    [self canvasExtentWithDstExtent:dstFrame.size.width
                          srcExtent:srcFrame.size.width
                      defaultExtent:_canvasSize.width],
    [self canvasExtentWithDstExtent:dstFrame.size.height
                          srcExtent:srcFrame.size.height
                      defaultExtent:_canvasSize.height]
  );
  
  [self initFilter:outSize];
  
  CGAffineTransform dstTransform = [IFKCompositionPostProcessor
                                    imageTransformWithCanvasWidth:outSize.width
                                    canvasHeight:outSize.height
                                    imageWidth:dstFrame.size.width
                                    imageHeight:dstFrame.size.height
                                    scale:_dstScale
                                    anchor:_dstAnchor
                                    position:_dstPosition
                                    rotate:_dstRotate];
  
  CGAffineTransform srcTransform = [IFKCompositionPostProcessor
                                    imageTransformWithCanvasWidth:outSize.width
                                    canvasHeight:outSize.height
                                    imageWidth:srcFrame.size.width
                                    imageHeight:srcFrame.size.height
                                    scale:_srcScale
                                    anchor:_srcAnchor
                                    position:_srcPosition
                                    rotate:_srcRotate];
  
  [[self filter] setValue:[srcImage imageByApplyingTransform:srcTransform]
                   forKey:_swapImages ? [self dstImageName] : @"inputImage"];
  
  [[self filter] setValue:[dstImage imageByApplyingTransform:dstTransform]
                   forKey:_swapImages ? @"inputImage" : [self dstImageName]];
  
  return [self filteredImageWithScale:image.scale
                           resizeMode:resizeMode
                            viewFrame:CGRectMake(0, 0, outSize.width, outSize.height)
                             destSize:outSize];
}

@end
