//
//  OpenGLView.m
//  SkiaInGL
//
//  Created by egret0 on 12/7/16.
//  Copyright © 2016 egret. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OpenGLView.h"
#include "General.h"
#include <SkCGUtils.h>
#include <SkPath.h>

typedef struct {
    float Position[3];
    float Color[4];
} Vertex;

const Vertex Vertices[] = {
    {{1, -1, 0}, {1, 0, 0, 1}},
    {{1, 1, 0}, {1, 0, 0, 1}},
    {{-1, 1, 0}, {0, 1, 0, 1}},
    {{-1, -1, 0}, {0, 1, 0, 1}},
    {{1, -1, -1}, {1, 0, 0, 1}},
    {{1, 1, -1}, {1, 0, 0, 1}},
    {{-1, 1, -1}, {0, 1, 0, 1}},
    {{-1, -1, -1}, {0, 1, 0, 1}}
};

const GLubyte Indices[] = {
    // Front
    0, 1, 2,
    2, 3, 0,
    // Back
    4, 6, 5,
    4, 7, 6,
    // Left
    2, 7, 3,
    7, 6, 2,
    // Right
    0, 4, 1,
    4, 1, 5,
    // Top
    6, 2, 1,
    1, 6, 5,
    // Bottom
    0, 3, 7,
    0, 7, 4
};

const GLfloat projection[] = {
    2.000000, 0.000000, 0.000000, 0.000000,
    0.000000, 1.126761, 0.000000, 0.000000,
    0.000000, 0.000000, -2.333333, -1.000000,
    0.000000, 0.000000, -13.333333, 0.000000
};

const GLfloat modelView[] = {
    1.000000, 0.000000, 0.000000, 0.000000,
    0.000000, 1.000000, 0.000000, 0.000000,
    0.000000, 0.000000, 1.000000, 0.000000,
    0.000000, 0.000000, -7.000000, 1.000000
};

GLfloat modelView2[] = {
    1.000000, 0.000000, 0.000000, 0.000000,
    0.000000, 1.000000, 0.000000, 0.000000,
    0.000000, 0.000000, 1.000000, 0.000000,
    0.000000, 1.000000, -7.000000, 1.000000
};

@implementation OpenGLView

+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (void) setupLayer
{
//    _eaglLayer = (CAEAGLLayer *)self.layer;
//    _eaglLayer.opaque = YES;
    _eaglLayer = [CAEAGLLayer layer];
    _eaglLayer.bounds = self.bounds;
    _eaglLayer.anchorPoint = CGPointMake(0, 0);
    _eaglLayer.opaque = YES;
    [self.layer addSublayer:_eaglLayer];
}

- (void) setupContext
{
    _context = General::getInstance()->_context;
}

- (void) setupDepthBuffer
{
    glGenRenderbuffers(1, &_depthRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, self.frame.size.width, self.frame.size.height);
}

- (void) setupRenderBuffer
{
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
}

- (void) setupFrameBuffer
{
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER,
                              _colorRenderBuffer);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRenderBuffer);
}

- (GLuint) compileShader:(NSString*)shaderName withType:(GLenum)shaderType
{
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName
                                                           ofType:@"glsl"];
    NSError* error;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString)
    {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    GLuint shaderHandle = glCreateShader(shaderType);
    
    const char* shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    glCompileShader(shaderHandle);
    
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE)
    {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
}

- (void) compileShaders
{
    GLuint vertexShader = [self compileShader:@"SimpleVertex"
                                     withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"SimpleFragment"
                                       withType:GL_FRAGMENT_SHADER];
    
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE)
    {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(programHandle);
    
    _positionSlot = glGetAttribLocation(programHandle, "Position");
    _colorSlot = glGetAttribLocation(programHandle, "SourceColor");
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_colorSlot);
    
    _projectionUniform = glGetUniformLocation(programHandle, "Projection");
    
    _modelViewUniform = glGetUniformLocation(programHandle, "Modelview");
}

- (void) setupVBOs
{
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    GLuint indexBuffer;
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
}

- (void) render:(CADisplayLink *)displayLink
{
    //skia
    SkPaint paint;
    paint.setColor(SK_ColorBLUE);
    paint.setAntiAlias(true);
    
    _canvas->clear(0x00000000);
    
    _canvas->drawText("AAA", 3, 50, 50, paint);
    
    _canvas->save();
    
    const SkScalar scale = 256.0f;
    const SkScalar R = 0.45f * scale;
    const SkScalar TAU = 6.2831853f;
    SkPath path;
    path.moveTo(R, 0.0f);
    for (int i = 1; i < 7; ++i) {
        SkScalar theta = 3 * i * TAU / 7;
        path.lineTo(R * cos(theta), R * sin(theta));
    }
    path.close();
    paint.setColor(SK_ColorRED);
    _canvas->translate(0.5f * scale, 0.5f * scale);
    _rot += 1;
    if (_rot > 360)
    {
        _rot -= 360;
    }
    _canvas->rotate(_rot);
    _canvas->drawPath(path, paint);
    
    _canvas->restore();
    
    CGImageRef cgImage = SkCreateCGImageRef(_bitmap);
    _rasterLayer.contents = (__bridge id)cgImage;
    CGImageRelease(cgImage);
    
    // gl
    glClearColor(0.5, 0.5, 1.0, 1.0);

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    
    glUniformMatrix4fv(_projectionUniform, 1, 0, projection);
    glUniformMatrix4fv(_modelViewUniform, 1, 0, modelView);
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) *3));
    
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]),
                   GL_UNSIGNED_BYTE, 0);
    
    float offsetX = displayLink.duration / 10;
    modelView2[12] += offsetX;
    if (modelView2[12] > 3.0)
    {
        modelView2[12] = -3.0;
    }
    
    glUniformMatrix4fv(_modelViewUniform, 1, 0, modelView2);
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]),
                   GL_UNSIGNED_BYTE, 0);
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
    glDisable(GL_DEPTH_TEST);
}

- (void) setupSkiaLayer
{
    _rasterLayer = [CALayer layer];
    _rasterLayer.bounds = self.bounds;
    _rasterLayer.anchorPoint = CGPointMake(0, 0);
    [self.layer addSublayer:_rasterLayer];
    
    _bitmap.allocN32Pixels(0, 0);
    SkImageInfo info = _bitmap.info().makeWH(_width, _height);
    _bitmap.allocPixels(info);
    
    _surface = SkSurface::MakeRasterDirect(_bitmap.info(), _bitmap.getPixels(), _bitmap.rowBytes());
    
    _canvas = _surface->getCanvas();
    
    _rot = 0;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _width = frame.size.width;
        _height = frame.size.height;
        
        [self setupLayer];
        [self setupSkiaLayer];
        [self setupContext];
        
        [self setupDepthBuffer];
        
        [self setupRenderBuffer];
        [self setupFrameBuffer];
        
        [self compileShaders];
        [self setupVBOs];
    }
    return self;
}

@end
