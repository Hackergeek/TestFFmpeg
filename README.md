# Android cmake编译FFmpeg

[**项目地址**](https://github.com/Hackergeek/TestFFmpeg)
通过阅读本文，你将学到以下内容：
1. 如何编译多种CPU指令集的FFmpeg动态库
2. 如何配置CMakeLists.txt和build.gradle构建Android项目
## 编译环境
1. ndk-r16
2. ffmpeg-4.0.2
## 一、交叉编译FFmpeg生成动态库
FFmpeg是一个强大的音视频处理库，我们有时候只需要用到这个库的部分功能，因此我们需要通过configure的一些选项对它进行裁剪。此外，我们还需要配置生成哪种CPU指令集的动态库、生成的动态库在什么操作系统上使用以及一些编译选项等。 
一个支持**armeabi-v7a、arm64-v8a、x86和x86_64**四种CPU指令集的FFmpeg编译脚本，内容如下：
```shell
#!/bin/sh

#  build.sh
#  Builds all supported architectures of FFmpeg for Android.
#  Versions: NDK - r16b, FFmpeg - 4.0.2

NDK=/Users/chenzhichang/Downloads/android-ndk-r16b
# MacOS：darwin-86_64
HOST=darwin-x86_64

# Takes three arguments:
# First: ARCH, supported values: armeabi-v7a, arm64-v8a, x86, x86_64
# Second: platform level. Range: 14-19, 21-24, 26-28
# Third: additinal configuration flags. Already present flags: --enable-cross-compile --disable-static --disable-programs --disable-doc --enable-shared --enable-protocol=file --enable-pic --enable-small
build () {
    ARCH=$1
    LEVEL=$2
    if [ ! $ARCH ]; then
       ARCH=armeabi-v7a
    fi 
    if [ ! $LEVEL ]; then
       LEVEL=21
    fi
    ISYSROOT=$NDK/sysroot
    PLATFORM_ARCH=
    CFLAGS=
    TARGET=
    TOOLCHAIN_FOLDER=
    
    CONFIGURATION="--disable-asm \
    --enable-cross-compile \
    --disable-static \
    --disable-programs \
    --disable-doc \
    --enable-shared \
    --enable-protocol=file \
    --enable-pic \
    --enable-small \
    --disable-devices \
    $3"
    

    case $ARCH in
        "armeabi-v7a")
            TARGET="arm-linux-androideabi"
            CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon"
            PLATFORM_ARCH="arm"
            TOOLCHAIN_FOLDER="arm-linux-androideabi"
        ;;
        "arm64-v8a")
            TARGET="aarch64-linux-android"
            CFLAGS="-march=armv8-a"
            PLATFORM_ARCH="arm64"
            CONFIGURATION="$CONFIGURATION --disable-pthreads"
            TOOLCHAIN_FOLDER="aarch64-linux-android"
        ;;
        "x86")
            TARGET="i686-linux-android"
            CFLAGS="-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32"
            PLATFORM_ARCH="x86"
            TOOLCHAIN_FOLDER="x86"
        ;;
        "x86_64")
            TARGET="x86_64-linux-android"
            CFLAGS="-march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel"
            PLATFORM_ARCH="x86_64"
            TOOLCHAIN_FOLDER="x86_64"
        ;;
    esac

    CROSS_PREFIX=$NDK/toolchains/$TOOLCHAIN_FOLDER-4.9/prebuilt/$HOST/bin/$TARGET-
    ASM=$ISYSROOT/usr/include/$TARGET
    SYSROOT=$NDK/platforms/android-$LEVEL/arch-$PLATFORM_ARCH/
    PREFIX="android/$ARCH"

    ./configure --prefix=$PREFIX  \
                $CONFIGURATION \
                --cross-prefix=$CROSS_PREFIX \
                --arch=$PLATFORM_ARCH \
                --target-os=android \
                --sysroot=$SYSROOT \
                --extra-cflags="$CFLAGS -I$ASM -isysroot $ISYSROOT -D__ANDROID_API__=$LEVEL -Wfatal-errors -U_FILE_OFFSET_BITS -Os -fPIC -DANDROID -D__thumb__ -Wno-deprecated" 

    make clean
    make -j4
    make install
}
#build "armeabi-v7a" "21"
#build "arm64-v8a" "21"
#build "x86_64" "21"
#build "x86" "21"
```
这个脚本的用法很简单，只需要将该脚本文件拷贝到ffmpeg源码的根目录下，将脚本中的NDK变量值改为你的电脑上NDK所在的路径。如果你的电脑不是Mac，则还需要修改HOST变量值。最后执行下面这条命令即可。其中armeabi-v7a表示CPU指令集，21表示Android版本。
```shell
./build.sh armeabi-v7a 21
```
 在这里简单介绍一下关于此脚本的一些配置项，从而方便你能够根据你的需求来修改这个脚本：
1. --prefix：指定编译输出的文件路径
2. --target-os：指定目标操作系统
3. --disable-static：禁止生成静态库
4. --disable-programs：禁止生成ffplay、ffmpeg等可执行文件
5. --disable-doc：禁止生成文档
6. --enable-shared：生成动态动态链接库
7. --enable-cross-compile：开启交叉编译（跨平台编译）

执行此脚本，最终生成文件如下：

![20181006165801357.png](https://upload-images.jianshu.io/upload_images/1532904-ead064a591014e65.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
## 二、创建NDK项目并引入FFmpeg动态库

![20181006111010365.png](https://upload-images.jianshu.io/upload_images/1532904-8fb661962ffe2536.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
## 三、配置build.gradle
需要配置的内容如下：
1. 配置so库的路径
2. 配置cmake编译选项和支持的CPU指令集，其中-Wno-deprecated-declarations选项用于忽略使用废弃API的编译警告。
3. 配置CMakeLists.txt文件的路径

最终配置如下：
```grovvy
apply plugin: 'com.android.application'

android {
    compileSdkVersion 28
    defaultConfig {
        applicationId "com.chenzhichang.testffmpeg"
        minSdkVersion 15
        targetSdkVersion 28
        versionCode 1
        versionName "1.0"
        testInstrumentationRunner "android.support.test.runner.AndroidJUnitRunner"
        //配置so库的路径
        sourceSets {
            main {
                jniLibs.srcDirs = ['libs']
            }
        }
        //配置cmake编译选项和支持的CPU指令集
        externalNativeBuild {
            cmake {
                cppFlags "-frtti -fexceptions -Wno-deprecated-declarations"
            }
            ndk{
                abiFilters "armeabi-v7a", "x86_64", "x86"
            }
        }
    }
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
    //配置CMakeLists.txt文件的路径
    externalNativeBuild {
        cmake {
            path "CMakeLists.txt"
        }
    }
}

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
    implementation 'com.android.support:appcompat-v7:28.0.0'
    implementation 'com.android.support.constraint:constraint-layout:1.1.3'
    testImplementation 'junit:junit:4.12'
    androidTestImplementation 'com.android.support.test:runner:1.0.2'
    androidTestImplementation 'com.android.support.test.espresso:espresso-core:3.0.2'
}
         
```
## 四、配置CMakeLists.txt
配置如下：
```java
cmake_minimum_required(VERSION 3.4.1)

find_library( log-lib
              log )

# 定义变量
set(distribution_DIR ../../../../libs)

# 添加库——自己编写的库
# 库名称：native-lib
# 库类型：SHARED，表示动态库，后缀为.so（如果是STATIC，则表示静态库，后缀为.a）
# 库源码文件：src/main/cpp/native-lib.cpp
add_library( native-lib
             SHARED
             src/main/cpp/native-lib.cpp )

# 添加库——外部引入的库
# 库名称：avcodec（不需要包含前缀lib）
# 库类型：SHARED，表示动态库，后缀为.so（如果是STATIC，则表示静态库，后缀为.a）
# IMPORTED表明是外部引入的库
add_library( avcodec
             SHARED
             IMPORTED)
# 设置目标属性
# 设置avcodec目标库的IMPORTED_LOCATION属性，用于说明引入库的位置
# 还可以设置其他属性，格式：PROPERTIES key value
set_target_properties( avcodec
                       PROPERTIES IMPORTED_LOCATION
                       ${distribution_DIR}/${ANDROID_ABI}/libavcodec.so)

add_library( avfilter
             SHARED
             IMPORTED)
set_target_properties( avfilter
                       PROPERTIES IMPORTED_LOCATION
                       ${distribution_DIR}/${ANDROID_ABI}/libavfilter.so)

add_library( avformat
             SHARED
             IMPORTED)
set_target_properties( avformat
                       PROPERTIES IMPORTED_LOCATION
                       ${distribution_DIR}/${ANDROID_ABI}/libavformat.so)

add_library( avutil
             SHARED
             IMPORTED)
set_target_properties( avutil
                       PROPERTIES IMPORTED_LOCATION
                       ${distribution_DIR}/${ANDROID_ABI}/libavutil.so)

add_library( swresample
             SHARED
             IMPORTED)
set_target_properties( swresample
                       PROPERTIES IMPORTED_LOCATION
                       ${distribution_DIR}/${ANDROID_ABI}/libswresample.so)

add_library( swscale
             SHARED
             IMPORTED)
set_target_properties( swscale
                       PROPERTIES IMPORTED_LOCATION
                       ${distribution_DIR}/${ANDROID_ABI}/libswscale.so)

# 引入头文件
include_directories(libs/include)

# 告诉编译器生成native-lib库需要链接的库
# native-lib库需要依赖avcodec、avfilter等库
target_link_libraries( native-lib
                       avcodec
                       avfilter
                       avformat
                       avutil
                       swresample
                       swscale
                       ${log-lib} )
```
关于CMake的详细内容可以阅读[官方文档](https://cmake.org/documentation/)
## 五、编写代码测试FFmpeg是否能够正常使用
- activity_main.xml
```xml
<?xml version="1.0" encoding="utf-8"?>

<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    android:id="@+id/activity_main"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal">

        <Button
            android:id="@+id/btn_protocol"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_margin="2dp"
            android:text="Protocol"
            android:textAllCaps="false" />

        <Button
            android:id="@+id/btn_format"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_margin="2dp"
            android:text="Format"
            android:textAllCaps="false" />

        <Button
            android:id="@+id/btn_codec"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_margin="2dp"
            android:text="Codec"
            android:textAllCaps="false" />

        <Button
            android:id="@+id/btn_filter"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_margin="2dp"
            android:text="Filter"
            android:textAllCaps="false" />
    </LinearLayout>

    <ScrollView
        android:layout_width="match_parent"
        android:layout_height="wrap_content">

        <TextView
            android:id="@+id/tv_info"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="Hello World!" />
    </ScrollView>

</LinearLayout>
```
- native-lib.cpp
```C++
#include <jni.h>
#include <string>

extern "C"
{


#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
JNIEXPORT jstring JNICALL
Java_com_chenzhichang_testffmpeg_MainActivity_stringFromJNI(
        JNIEnv *env,
        jobject /* this */) {
    std::string hello = "Hello from C++";
    return env->NewStringUTF(hello.c_str());
}

JNIEXPORT jstring JNICALL
Java_com_chenzhichang_testffmpeg_MainActivity_urlprotocolinfo(JNIEnv *env, jobject instance) {
    char info[40000] = {0};
    av_register_all();
    struct URLProtocol *pup = NULL;
    struct URLProtocol **p_temp = &pup;
    avio_enum_protocols((void **) p_temp, 0);
    while ((*p_temp) != NULL) {
        sprintf(info, "%sInput: %s\n", info, avio_enum_protocols((void **) p_temp, 0));
    }
    pup = NULL;
    avio_enum_protocols((void **) p_temp, 1);
    while ((*p_temp) != NULL) {
        sprintf(info, "%sInput: %s\n", info, avio_enum_protocols((void **) p_temp, 1));
    }

    return env->NewStringUTF(info);
}

JNIEXPORT jstring JNICALL
Java_com_chenzhichang_testffmpeg_MainActivity_avformatinfo(JNIEnv *env, jobject instance) {

    char info[40000] = {0};

    av_register_all();

    AVInputFormat *if_temp = av_iformat_next(NULL);
    AVOutputFormat *of_temp = av_oformat_next(NULL);
    while (if_temp != NULL) {
        sprintf(info, "%sInput: %s\n", info, if_temp->name);
        if_temp = if_temp->next;
    }
    while (of_temp != NULL) {
        sprintf(info, "%sOutput: %s\n", info, of_temp->name);
        of_temp = of_temp->next;
    }
    return env->NewStringUTF(info);
}

JNIEXPORT jstring JNICALL
Java_com_chenzhichang_testffmpeg_MainActivity_avcodecinfo(JNIEnv *env, jobject instance) {
    char info[40000] = {0};

    av_register_all();

    AVCodec *c_temp = av_codec_next(NULL);

    while (c_temp != NULL) {
        if (c_temp->decode != NULL) {
            sprintf(info, "%sdecode:", info);
        } else {
            sprintf(info, "%sencode:", info);
        }
        switch (c_temp->type) {
            case AVMEDIA_TYPE_VIDEO:
                sprintf(info, "%s(video):", info);
                break;
            case AVMEDIA_TYPE_AUDIO:
                sprintf(info, "%s(audio):", info);
                break;
            default:
                sprintf(info, "%s(other):", info);
                break;
        }
        sprintf(info, "%s[%10s]\n", info, c_temp->name);
        c_temp = c_temp->next;
    }

    return env->NewStringUTF(info);
}

JNIEXPORT jstring JNICALL
Java_com_chenzhichang_testffmpeg_MainActivity_avfilterinfo(JNIEnv *env, jobject instance) {
    char info[40000] = {0};
    avfilter_register_all();

    AVFilter *f_temp = (AVFilter *) avfilter_next(NULL);
    while (f_temp != NULL) {
        sprintf(info, "%s%s\n", info, f_temp->name);
        f_temp = f_temp->next;
    }
    return env->NewStringUTF(info);
}
}
```
- MainActivity.java
```java
package com.chenzhichang.testffmpeg;

import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

/**
 * @author chenzhichang
 */
public class MainActivity extends AppCompatActivity implements View.OnClickListener {

    // Used to load the 'native-lib' library on application startup.
    static {
        System.loadLibrary("native-lib");
    }


    TextView tvInfo;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        ((Button)findViewById(R.id.btn_protocol)).setOnClickListener(this);
        ((Button)findViewById(R.id.btn_codec)).setOnClickListener(this);
        findViewById(R.id.btn_filter).setOnClickListener(this);
        findViewById(R.id.btn_format).setOnClickListener(this);
        tvInfo = (TextView) findViewById(R.id.tv_info);
    }



    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.btn_protocol:
                tvInfo.setText(urlprotocolinfo());
                break;
            case R.id.btn_format:
                tvInfo.setText(avformatinfo());
                break;
            case R.id.btn_codec:
                tvInfo.setText(avcodecinfo());
                break;
            case R.id.btn_filter:
                tvInfo.setText(avfilterinfo());
                break;
            default:
                break;
        }
    }

    public native String stringFromJNI();

    public native String urlprotocolinfo();

    public native String avformatinfo();

    public native String avcodecinfo();

    public native String avfilterinfo();
}
```
### 运行结果如下图：
![Jietu20181006-172358-HD.gif](https://upload-images.jianshu.io/upload_images/1532904-e4c84ccb2edef526.gif?imageMogr2/auto-orient/strip)
## 参考资料
[IljaKosynkin/FFmpeg-Development-Kit](https://github.com/IljaKosynkin/FFmpeg-Development-Kit)

[ffmpeg使用NDK编译时遇到的一些坑 - luo0xue的博客 - CSDN博客](https://blog.csdn.net/luo0xue/article/details/80048847#commentBox)

[ffmpeg ./configure参数说明 - azraelly - 博客园](https://www.cnblogs.com/azraelly/archive/2012/12/31/2840541.html)

[Android开发学习之路--Android Studio cmake编译ffmpeg - 东月之神 - CSDN博客](https://blog.csdn.net/eastmoon502136/article/details/52806640)
