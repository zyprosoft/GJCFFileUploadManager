//
//  GJCFXXUploadImageViewController.m
//  GJCommonFoundation
//
//  Created by ZYVincent on 14-9-13.
//  Copyright (c) 2014年 ZYProSoft.com. All rights reserved.
//

#import "GJCFXXUploadImageViewController.h"
#import "GJCFFileUploadManager.h"
#import "XXUploadInterfaceConstans.h"
#import "TVGDebugQuickUI.h"
#import "GJCFAssetsPickerViewController.h"
#import "DAProgressOverlayView.h"
#import "UIView+GJCFViewFrameUitil.h"
#import "AFHTTPRequestOperationManager.h"
#import "AFHTTPRequestOperation.h"

#define XXImageViewBaseTag 112233

#define XXImagViewOverlayViewTag 113322

#define XXImagViewStateLabelTag 332211


@interface GJCFXXUploadImageViewController ()<GJCFAssetsPickerViewControllerDelegate>

@property (nonatomic,strong)NSMutableDictionary *userInfo;

@property (nonatomic,strong)NSMutableArray *currentSelectedImagesArray;

@property (nonatomic,strong)NSMutableArray *taskUniqueIdsArray;

@property (nonatomic,strong)UIActivityIndicatorView *hud;

@property (nonatomic,strong)GJCFFileUploadManager *fileUploadManager;

@property (nonatomic,strong)AFHTTPRequestOperationManager *requestOperationManager;

@end

@implementation GJCFXXUploadImageViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.currentSelectedImagesArray = [[NSMutableArray alloc]init];
    self.taskUniqueIdsArray = [[NSMutableArray alloc]init];
    
    UIButton *loginBtn = [TVGDebugQuickUI buttonAddOnView:self.view title:@"登录" target:self selector:@selector(loginAction)];
    loginBtn.gjcf_top = 88;
    loginBtn.gjcf_left = 0;
    
    UIButton *chooseBtn = [TVGDebugQuickUI buttonAddOnView:self.view title:@"选择照片" target:self selector:@selector(chooseImageAction)];
    chooseBtn.gjcf_top = 88;
    chooseBtn.gjcf_left = 110;
    
    UIButton *uploadBtn = [TVGDebugQuickUI buttonAddOnView:self.view title:@"上传" target:self selector:@selector(uploadAction)];
    uploadBtn.gjcf_top = 88;
    uploadBtn.gjcf_left = 200;
    
    self.hud = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.hud.frame = (CGRect){100,250,60,60};
    [self.view addSubview:self.hud];
    self.hud.hidden = YES;
    
    /* 
     * 初始化
     * 为文件上传组件设定默认的HttpHeader
     */
    self.fileUploadManager = [[GJCFFileUploadManager alloc]initWithOwner:self];
    [self.fileUploadManager setDefaultHostUrl:[XXUploadInterfaceConstans imageServer]];
    [self.fileUploadManager setDefaultUploadPath:[XXUploadInterfaceConstans imageUploadPath]];
    
    /* 观察上传状态 */
    [self observeUploadTask];
}

#pragma mark - Login
- (void)loginAction
{
    NSString *userName = @"123a@qq.com";
    NSString *pwd = @"123123";
    
    self.requestOperationManager = [[AFHTTPRequestOperationManager alloc]initWithBaseURL:[NSURL URLWithString:[XXUploadInterfaceConstans imageServer]]];

    NSDictionary *params = @{@"account":userName,@"password":pwd};
    
    self.hud.hidden = NO;
    [self.hud startAnimating];
    
    [self.requestOperationManager POST:[XXUploadInterfaceConstans loginUserPath] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *resultDict = (NSDictionary *)responseObject;
        
        NSLog(@"resultDict:%@",[resultDict objectForKey:@"msg"]);
        
        NSDictionary *userData = [resultDict objectForKey:@"user"];
        self.userInfo = [NSMutableDictionary dictionaryWithDictionary:userData];
        [self.userInfo setObject:[resultDict objectForKey:@"token"] forKey:@"token"];
        
        NSLog(@"login success:%@",self.userInfo);
        [self.hud stopAnimating];
        self.hud.hidden = YES;
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"xximageUpload login faild :%@",error);
        [self.hud stopAnimating];
        self.hud.hidden = YES;
        
    }];
}

- (void)chooseImageAction
{
    GJCFAssetsPickerViewController *assetsPicker = [[GJCFAssetsPickerViewController alloc]init];
    assetsPicker.mutilSelectLimitCount = 4;
    assetsPicker.pickerDelegate = self;
    [self presentViewController:assetsPicker animated:YES completion:NULL];
}

- (void)showImages
{

    
    CGFloat itemImgViewWidth = 80;
    for (int i = 0 ; i < self.currentSelectedImagesArray.count ; i++) {
        
        UIImageView *contentImgView = (UIImageView*)[self.view viewWithTag:XXImageViewBaseTag+i];
        UILabel     *stateLabel = (UILabel*)[self.view viewWithTag:XXImagViewStateLabelTag+i];
        GJCFAsset *asset = [self.currentSelectedImagesArray objectAtIndex:i];
        
        if (!contentImgView) {
            
            contentImgView = [[UIImageView alloc]init];
            
            contentImgView.frame = (CGRect){50,itemImgViewWidth*(i+1)+5*(i+1)+70,itemImgViewWidth,itemImgViewWidth};
            
            contentImgView.tag = XXImageViewBaseTag+i;
            
            contentImgView.image = asset.thumbnail;
            
            [self.view addSubview:contentImgView];
            
            /* 进度视图 */
            DAProgressOverlayView *progressView = [[DAProgressOverlayView alloc]initWithFrame:contentImgView.bounds];
            progressView.tag = XXImagViewOverlayViewTag+i;
            progressView.progress = 0.f;
            progressView.hidden = YES;
            progressView.overlayColor = [UIColor colorWithRed:0.2 green:0.3 blue:0.7 alpha:1];
            [contentImgView addSubview:progressView];
            
            /* 上传成功标签 */
            UILabel *stateLabel = [[UILabel alloc]init];
            stateLabel.frame = (CGRect){50 + itemImgViewWidth,itemImgViewWidth*(i+1)+5*(i+1)+70,itemImgViewWidth*2,itemImgViewWidth};
            stateLabel.text = @"等待上传";
            stateLabel.numberOfLines = 0;
            stateLabel.textAlignment = NSTextAlignmentCenter;
            stateLabel.tag = XXImagViewStateLabelTag + i;
            stateLabel.font = [UIFont systemFontOfSize:16];
            [self.view addSubview:stateLabel];

        }else{
            
            stateLabel.text = @"等待上传";
            contentImgView.image = asset.thumbnail;
        }
    }
    
    /* 隐藏没有选择的 */
    for (NSInteger i = self.currentSelectedImagesArray.count; i < 4; i++) {
        
        UIImageView *contentImgView = (UIImageView*)[self.view viewWithTag:XXImageViewBaseTag+i];
        contentImgView.hidden = YES;
    }
}

//监视上传任务的状态
- (void)observeUploadTask
{
    /* 创建自身弱引用指针，避免循环引用问题 */
    __weak typeof(self)weakSelf = self;
    
    [self.fileUploadManager setProgressBlock:^(GJCFFileUploadTask *updateTask,CGFloat progressValue){
        
        dispatch_async(dispatch_get_main_queue(), ^{
           
            UIImageView *taskImgView = (UIImageView *)[weakSelf.view viewWithTag:XXImageViewBaseTag + updateTask.customTaskIndex];
            DAProgressOverlayView *progressView = (DAProgressOverlayView*)[taskImgView viewWithTag:XXImagViewOverlayViewTag + updateTask.customTaskIndex];
            
            progressView.hidden = NO;
            [progressView setProgress:progressValue];
            
        });
        
        
    }];
    
    [self.fileUploadManager setCompletionBlock:^(GJCFFileUploadTask *task,NSDictionary *resultDict){
        
        
        if ([[resultDict objectForKey:@"ret"]intValue] == 0) {
            
            NSLog(@"XXImageUpload: taskId:%@ success result:%@",task.uniqueIdentifier,resultDict);

        }else{
            
            NSLog(@"XXImageUpload: taskId:%@ faild msg:%@",task.uniqueIdentifier,[resultDict objectForKey:@"result"][@"msg"]);

        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIImageView *taskImgView = (UIImageView *)[weakSelf.view viewWithTag:XXImageViewBaseTag + task.customTaskIndex];
            DAProgressOverlayView *progressView = (DAProgressOverlayView*)[taskImgView viewWithTag:XXImagViewOverlayViewTag + task.customTaskIndex];
            progressView.hidden = YES;
            
            UILabel *stateLabel = (UILabel*)[weakSelf.view viewWithTag:XXImagViewStateLabelTag + task.customTaskIndex];
            stateLabel.text = [NSString stringWithFormat:@"上传成功\nurl:%@",resultDict[@"result"][@"link"]];
            
        });
        
    }];
    
    [self.fileUploadManager setFaildBlock:^(GJCFFileUploadTask *task,NSError *error){
        
        NSLog(@"XXImageUpload: taskId:%@ faild result:%@",task.uniqueIdentifier,error);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIImageView *taskImgView = (UIImageView *)[weakSelf.view viewWithTag:XXImageViewBaseTag + task.customTaskIndex];
            DAProgressOverlayView *progressView = (DAProgressOverlayView*)[taskImgView viewWithTag:XXImagViewOverlayViewTag + task.customTaskIndex];
            progressView.hidden = YES;
            
            UILabel *stateLabel = (UILabel*)[weakSelf.view viewWithTag:XXImagViewStateLabelTag + task.customTaskIndex];
            stateLabel.text = [NSString stringWithFormat:@"上传失败\ntaskId:%@",task.uniqueIdentifier];
            
        });
        
    }];
    
}

- (void)uploadAction
{
    if (![self.userInfo objectForKey:@"token"]) {
        
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"提示" message:[NSString stringWithFormat:@"请先登录"] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [alert show];
        
        return;
    }
    
    if (self.currentSelectedImagesArray.count > 0) {
        
        [self.currentSelectedImagesArray enumerateObjectsUsingBlock:^(GJCFAsset *asset, NSUInteger idx, BOOL *stop) {
            
            /* 创建待上传文件对象 */
            GJCFUploadFileModel *imageFile = [GJCFUploadFileModel fileModelWithFileName:asset.fileName withFileData:nil withFormName:@"upload"];
            imageFile.isUploadAsset = YES;
            imageFile.contentAsset = asset.containtAsset;
            
            NSString *taskId = nil;
            
            /* 创建上传任务 */
            GJCFFileUploadTask *singleImageUploadTask = [GJCFFileUploadTask taskForFile:imageFile getTaskUniqueIdentifier:&taskId];
            singleImageUploadTask.customTaskIndex = idx;
            
            //自定义的httpHeader
            NSDictionary *customHttpHeaders = @{@"tooken": [self.userInfo objectForKey:@"token"]};
            singleImageUploadTask.customRequestHeader = customHttpHeaders;
            
            //自定义参数这里没有
            
            if (taskId) {
                [self.taskUniqueIdsArray addObject:taskId];
            }
            
            //开始上传任务
            [self.fileUploadManager addTask:singleImageUploadTask];
            
            UILabel *stateLabel = (UILabel*)[self.view viewWithTag:XXImagViewStateLabelTag + idx];
            stateLabel.text = @"上传图片中...";
            
        }];
        
    }
}

#pragma mark - GJAssetsPicker delegate
- (void)pickerViewController:(GJCFAssetsPickerViewController *)pickerViewController didFinishChooseMedia:(NSArray *)resultArray
{
    [self.currentSelectedImagesArray addObjectsFromArray:resultArray];
    
    [self showImages];
    
    [pickerViewController dismissPickerViewController];
}

- (void)pickerViewController:(GJCFAssetsPickerViewController *)pickerViewController didReachLimitSelectedCount:(NSInteger)limitCount
{
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"提示" message:[NSString stringWithFormat:@"超过限制%d张数",limitCount] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    [alert show];
}

- (void)pickerViewControllerRequirePreviewButNoSelectedImage:(GJCFAssetsPickerViewController *)pickerViewController
{
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"提示" message:[NSString stringWithFormat:@"请选择要预览的图片"] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    [alert show];
}

- (void)pickerViewControllerPhotoLibraryAccessDidNotAuthorized:(GJCFAssetsPickerViewController *)pickerViewController
{
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"提示" message:[NSString stringWithFormat:@"请授权访问你的相册"] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    [alert show];
}



@end
