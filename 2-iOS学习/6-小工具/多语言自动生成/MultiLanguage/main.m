//
//  main.m
//  MultiLanguage
//
//  Created by User on 2019/11/4.
//  Copyright © 2019 User. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XlsxReaderWriter.h"

//KEY的生成规则：选取多少个单词当作Key值,目前是3个，例如"ASC_THIS_OPERATION_IS_RISKY"
//搜索“作用：选取多少个单词当作Key值”，就能找到位置

//【几种语言几种列】表格排序： 英文、中文 ，同NSArray *lanArr 一致
//流程是：1.创建表格，2.填入表格路径excelPath ， 3.在输出目录outputDirectory 有对应文件夹 4.修改前缀rfpName 5.运行
//以下三个常量需要修改
static NSString * excelPath = @"/Users/qqz/Desktop/0401.xlsx";  //多语言表格路径
static NSString * outputDirectory = @"/Users/qqz/Desktop/haha"; //输出目录
static NSString * rfpName = @"ASC";  //前缀
//以下常量不需要修改

static char EnKeyColumn = 'A';  //从哪列开始
static const NSInteger StartRowIndex = 1;// 从哪行开始
static const NSInteger MaxRowIndex = 3000;//最多支持几行
static NSString * rfp_template = @"RFP_NAME";//不用管

void newTranslate(BRAWorksheet *worksheet, NSArray<NSString *> *lanArr);
NSString *getKeyByEnValue(NSString *enValue, NSInteger rowIndex, NSMutableDictionary<NSNumber *, NSString *> *keyDict);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        BRAOfficeDocumentPackage *spreadsheet = [BRAOfficeDocumentPackage open:excelPath];
        BRAWorksheet *worksheet = spreadsheet.workbook.worksheets[0];
        
        // 列的语言需要按照这个顺序来
        NSArray *lanArr = @[
            @"en",
            @"zh",
            @"th", 
        ];

        newTranslate(worksheet, lanArr);
        
    }
    return 0;
}

void newTranslate(BRAWorksheet *worksheet, NSArray<NSString *> *lanArr) {

    NSString *containerDirectory = [NSString stringWithFormat:@"%@/%@", outputDirectory, rfpName];
    [[NSFileManager defaultManager] removeItemAtPath:containerDirectory error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:containerDirectory withIntermediateDirectories:NO attributes:nil error:nil];
    
    
    NSMutableDictionary<NSNumber *, NSString *> *keyDict = [NSMutableDictionary dictionary];
    
    for (NSInteger lanIndex = 0; lanIndex < lanArr.count; lanIndex++) {
        
        NSMutableArray *resultStrArr = [NSMutableArray array];
        NSLog(@"%@ start", lanArr[lanIndex]);
        for (NSInteger rowIndex = StartRowIndex; rowIndex < MaxRowIndex; rowIndex++) {
            
            NSString *enCell = [NSString stringWithFormat:@"%c%ld", EnKeyColumn, rowIndex];
            NSString *curCell = [NSString stringWithFormat:@"%c%ld", (char)(EnKeyColumn+lanIndex), rowIndex];
            
            NSString *enCellContent = [[worksheet cellForCellReference:enCell] stringValue];
            NSString *valueCellContent = [[worksheet cellForCellReference:curCell] stringValue];
            
            if (!enCellContent.length) {
                continue;
            }
            
            NSString *keyContent = getKeyByEnValue(enCellContent, rowIndex, keyDict);
            
            
            if (!valueCellContent.length) {
                NSLog(@"%@ not found", keyContent);
                valueCellContent = @"";
            }
            valueCellContent = [valueCellContent stringByReplacingOccurrencesOfString:@"%s" withString:@"%@"];
            valueCellContent = [valueCellContent stringByReplacingOccurrencesOfString:@"%1$s" withString:@"%1$@"];
            valueCellContent = [valueCellContent stringByReplacingOccurrencesOfString:@"%2$s" withString:@"%2$@"];
            valueCellContent = [valueCellContent stringByReplacingOccurrencesOfString:@"%3$s" withString:@"%3$@"];

            [resultStrArr addObject:[NSString stringWithFormat:@"\"%@\" = \"%@\";", keyContent, valueCellContent]];
            
            [resultStrArr addObject:@"\n\n"];
        }
        
        NSString *lanContainerDirectory = [NSString stringWithFormat:@"%@/%@.lproj", containerDirectory, lanArr[lanIndex]];
        [[NSFileManager defaultManager] createDirectoryAtPath:lanContainerDirectory withIntermediateDirectories:NO attributes:nil error:nil];
        
        NSString *targetFilePath = [NSString stringWithFormat:@"%@/%@.strings", lanContainerDirectory, rfpName];
        
        NSMutableString *resultStr = [NSMutableString string];
        for (NSString *str in resultStrArr) {
            [resultStr appendString:str];
        }
        [resultStr writeToFile:targetFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        if ([lanContainerDirectory containsString:@"en.lproj"]) {
            NSString *baseLanContainerDirectory  = [lanContainerDirectory stringByReplacingOccurrencesOfString:@"en.lproj" withString:@"Base.lproj"];
            [[NSFileManager defaultManager] createDirectoryAtPath:baseLanContainerDirectory withIntermediateDirectories:NO attributes:nil error:nil];
            NSString *targetFilePath = [NSString stringWithFormat:@"%@/%@.strings", baseLanContainerDirectory, rfpName];
            [resultStr writeToFile:targetFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }
    
    
    {
        NSString *localizableHPath = [NSString stringWithFormat:@"%@/%@Localizable.h", containerDirectory, rfpName];
        NSMutableString *resultStr = [NSMutableString string];
        [keyDict enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *string = [NSString stringWithFormat:@"#define %@ @\"%@\"", obj, obj];
            [resultStr appendString:string];
            [resultStr appendString:@"\n\n"];
        }];

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *hUrl = [mainBundle URLForResource:@"LocalizableH" withExtension:@"txt"];
        
        NSString *hStr = [NSString stringWithContentsOfURL:hUrl encoding:NSUTF8StringEncoding error:nil];
        hStr = [hStr stringByReplacingOccurrencesOfString:rfp_template withString:rfpName];
        [resultStr appendString:hStr];
        
        [resultStr writeToFile:localizableHPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }


    {
        NSString *localizableMPath = [NSString stringWithFormat:@"%@/%@Localizable.m", containerDirectory, rfpName];
        NSMutableString *resultStr = [NSMutableString string];
  
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *mUrl = [mainBundle URLForResource:@"LocalizableM" withExtension:@"txt"];
        
        NSString *mStr = [NSString stringWithContentsOfURL:mUrl encoding:NSUTF8StringEncoding error:nil];
        mStr = [mStr stringByReplacingOccurrencesOfString:rfp_template withString:rfpName];
        [resultStr appendString:mStr];
        
        [resultStr writeToFile:localizableMPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    
}


NSString *getKeyByEnValue(NSString *enValue, NSInteger rowIndex, NSMutableDictionary<NSNumber *, NSString *> *keyDict) {

    if ([keyDict objectForKey:@(rowIndex)]) {
        return [keyDict objectForKey:@(rowIndex)];
    }
    
    
    NSArray<NSString *> *strArr = [enValue componentsSeparatedByString:@" "];
    NSString *resValue = nil;
    //作用：选取多少个单词当作Key值,目前是3个
    //选前三个
    if (strArr.count > 3) {
        resValue = [NSString stringWithFormat:@"%@_%@_%@_%@", strArr[0], strArr[1], strArr[2], strArr[3]];
    } else if (strArr.count > 2) {
        resValue = [NSString stringWithFormat:@"%@_%@_%@", strArr[0], strArr[1],strArr[2]];
    } else  if (strArr.count > 1) {
        resValue = [NSString stringWithFormat:@"%@_%@", strArr[0], strArr[1]];
    } else {
        resValue = strArr[0];
    }
        
    NSError *error = nil;
    NSString *pattern = @"[^a-zA-Z0-9_]";//正则取反
    NSRegularExpression *regularExpress = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];//这个正则可以去掉所有特殊字符和标点
    resValue = [regularExpress stringByReplacingMatchesInString:resValue options:0 range:NSMakeRange(0, [resValue length]) withTemplate:@""];
     
    resValue = [NSString stringWithFormat:@"%@_%@", rfpName, resValue];
    resValue = [resValue uppercaseString];

    __block BOOL keyEnable = NO;
    
    while (keyEnable == NO) {
        
        keyEnable = YES;
        
        [keyDict enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            if ([resValue isEqualToString:obj]) {
                keyEnable = NO;
                *stop = YES;
            }
        }];
        
        if (!keyEnable) {
            resValue = [resValue stringByAppendingString:@"_CP"];
        }
        
    };
    

    [keyDict setObject:resValue forKey:@(rowIndex)];
    
    return resValue;
    
}

