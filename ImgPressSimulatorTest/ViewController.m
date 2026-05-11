//
//  ViewController.m
//  ImgPressSimulatorTest
//
//  Created by Computer  on 09/05/26.
//


#import "ViewController.h"
#import "ImageCompressionManager.h"

@interface CompressionResultItem : NSObject
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, assign) CGFloat originalSizeKB;
@property (nonatomic, assign) NSInteger originalWidth;
@property (nonatomic, assign) NSInteger originalHeight;
@property (nonatomic, assign) CGFloat compressedSizeKB;
@property (nonatomic, assign) NSInteger compressedWidth;
@property (nonatomic, assign) NSInteger compressedHeight;
@property (nonatomic, strong) NSString *outputPath;
@end

@implementation CompressionResultItem
@end

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSString *documentsDirectory;
@property (nonatomic, strong) NSString *inputDir;
@property (nonatomic, strong) NSString *outputDir;
@property (nonatomic, strong) NSString *reportPath;

// UI Components
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *conditionLabel;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *loadingView;

// Data
@property (nonatomic, strong) NSMutableArray<CompressionResultItem *> *failedItems;
@property (nonatomic, assign) NSInteger totalImageCount;
@property (nonatomic, assign) CGFloat totalOriginalSizeKB;
@property (nonatomic, assign) CGFloat totalCompressedSizeKB;
@property (nonatomic, assign) NSInteger failedCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"压缩测试结果";
    
    // 获取应用 Documents 目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    _documentsDirectory = [paths firstObject];
    _inputDir = [_documentsDirectory stringByAppendingPathComponent:@"input_images"];
    _outputDir = [_documentsDirectory stringByAppendingPathComponent:@"output_images"];
    _reportPath = [_documentsDirectory stringByAppendingPathComponent:@"compression_report.txt"];
    
    _failedItems = [NSMutableArray array];
    
    [self setupUI];
    [self showLoading];
    
    // 延迟执行压缩测试
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self runCompressionTest];
    });
}

- (void)setupUI {
    // 创建Header视图（固定，不滚动）
    _headerView = [[UIView alloc] init];
    _headerView.translatesAutoresizingMaskIntoConstraints = NO;
    _headerView.backgroundColor = [UIColor systemRedColor];
    [self.view addSubview:_headerView];
    
    // 标题标签
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = @"压缩质量不合格报告";
    _titleLabel.font = [UIFont boldSystemFontOfSize:18];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [_headerView addSubview:_titleLabel];
    
    // 压缩条件标签
    _conditionLabel = [[UILabel alloc] init];
    _conditionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _conditionLabel.font = [UIFont systemFontOfSize:12];
    _conditionLabel.textColor = [UIColor whiteColor];
    _conditionLabel.textAlignment = NSTextAlignmentCenter;
    _conditionLabel.numberOfLines = 0;
    _conditionLabel.text = @"质量阈值 - 最小:300KB 最大:600KB 最小长边:256 最大长边:4096";
    [_headerView addSubview:_conditionLabel];
    
    // 统计标签
    _statsLabel = [[UILabel alloc] init];
    _statsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statsLabel.font = [UIFont systemFontOfSize:14];
    _statsLabel.textColor = [UIColor whiteColor];
    _statsLabel.textAlignment = NSTextAlignmentCenter;
    _statsLabel.numberOfLines = 0;
    [_headerView addSubview:_statsLabel];
    
    // 创建TableView（可滚动）
    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _tableView.backgroundColor = [UIColor systemBackgroundColor];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ResultCell"];
    [self.view addSubview:_tableView];
    
    // 设置约束（使用安全区域）
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    [NSLayoutConstraint activateConstraints:@[
        // Header View
        [_headerView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [_headerView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [_headerView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        
        // Title Label
        [_titleLabel.topAnchor constraintEqualToAnchor:_headerView.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:16],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-16],
        
        // Condition Label
        [_conditionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_conditionLabel.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:16],
        [_conditionLabel.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-16],
        
        // Stats Label
        [_statsLabel.topAnchor constraintEqualToAnchor:_conditionLabel.bottomAnchor constant:8],
        [_statsLabel.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:16],
        [_statsLabel.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-16],
        [_statsLabel.bottomAnchor constraintEqualToAnchor:_headerView.bottomAnchor constant:-16],
        
        // Table View
        [_tableView.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor]
    ]];
}

- (void)showLoading {
    if (_loadingView) {
        [_loadingView removeFromSuperview];
    }
    
    _loadingView = [[UIView alloc] initWithFrame:self.view.bounds];
    _loadingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    _loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_loadingView];
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 150, 100)];
    contentView.center = _loadingView.center;
    contentView.backgroundColor = [UIColor whiteColor];
    contentView.layer.cornerRadius = 10;
    [_loadingView addSubview:contentView];
    
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    indicator.center = CGPointMake(contentView.bounds.size.width / 2, 35);
    [indicator startAnimating];
    [contentView addSubview:indicator];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 60, contentView.bounds.size.width, 30)];
    label.text = @"压缩中";
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:14];
    [contentView addSubview:label];
}

- (void)hideLoading {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_loadingView removeFromSuperview];
        self->_loadingView = nil;
    });
}

- (void)updateStatsLabel {
    ImageCompressionManager *manager = [ImageCompressionManager sharedManager];
    NSString *compressorName = [manager currentCompressorName];
    NSString *statsText = [NSString stringWithFormat:@"压缩器: %@\n图片数量: %ld | 不合格: %ld | 压缩率: %.1f%%",
                           compressorName,
                           (long)_totalImageCount,
                           (long)_failedCount,
                           _totalOriginalSizeKB > 0 ? (_totalOriginalSizeKB - _totalCompressedSizeKB) / _totalOriginalSizeKB * 100 : 0];
    _statsLabel.text = statsText;
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _failedItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ResultCell" forIndexPath:indexPath];
    
    CompressionResultItem *item = _failedItems[indexPath.row];
    
    // 创建自定义内容视图
    UIView *contentView = [[UIView alloc] initWithFrame:cell.contentView.bounds];
    contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // 清除旧内容
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // 文件名（红色加粗）
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, cell.contentView.bounds.size.width - 32, 20)];
    nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    nameLabel.text = item.fileName;
    nameLabel.font = [UIFont boldSystemFontOfSize:16];
    nameLabel.textColor = [UIColor systemRedColor];
    [cell.contentView addSubview:nameLabel];
    
    // 原始信息（灰色）
    UILabel *originalLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 30, cell.contentView.bounds.size.width - 32, 18)];
    originalLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    originalLabel.text = [NSString stringWithFormat:@"原始: %.2f KB | %ld x %ld",
                          item.originalSizeKB, (long)item.originalWidth, (long)item.originalHeight];
    originalLabel.font = [UIFont systemFontOfSize:13];
    originalLabel.textColor = [UIColor secondaryLabelColor];
    [cell.contentView addSubview:originalLabel];
    
    // 压缩后信息（蓝色）
    UILabel *compressedLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 50, cell.contentView.bounds.size.width - 32, 18)];
    compressedLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    compressedLabel.text = [NSString stringWithFormat:@"压缩后: %.2f KB | %ld x %ld",
                            item.compressedSizeKB, (long)item.compressedWidth, (long)item.compressedHeight];
    compressedLabel.font = [UIFont systemFontOfSize:13];
    compressedLabel.textColor = [UIColor systemBlueColor];
    [cell.contentView addSubview:compressedLabel];
    
    // 路径信息（绿色小字）
    UILabel *pathLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 70, cell.contentView.bounds.size.width - 32, 16)];
    pathLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    pathLabel.text = item.outputPath;
    pathLabel.font = [UIFont systemFontOfSize:11];
    pathLabel.textColor = [UIColor systemGreenColor];
    [cell.contentView addSubview:pathLabel];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100;
}

#pragma mark - Compression Test

- (void)runCompressionTest {
    NSLog(@"=== 开始压缩测试 ===");
    
    CGFloat minCompressedSizeKB = 300.0;
    CGFloat maxCompressedSizeKB = 600.0;
    NSInteger minLongEdge = 256;
    NSInteger maxLongEdge = 4096;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:_outputDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSError *error = nil;
    NSArray *files = [fm contentsOfDirectoryAtPath:_inputDir error:&error];
    
    if (error) {
        NSLog(@"错误：无法读取输入目录: %@", error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.titleLabel.text = @"错误";
            self.statsLabel.text = @"无法读取输入目录";
            [self hideLoading];
        });
        return;
    }
    
    NSArray *imageExtensions = @[@"jpg", @"jpeg", @"png", @"gif"];
    NSMutableArray *imageFiles = [NSMutableArray array];
    
    for (NSString *file in files) {
        NSString *extension = [[file pathExtension] lowercaseString];
        if ([imageExtensions containsObject:extension]) {
            [imageFiles addObject:file];
        }
    }
    
    _totalImageCount = imageFiles.count;
    _totalOriginalSizeKB = 0;
    _totalCompressedSizeKB = 0;
    _failedCount = 0;
    [_failedItems removeAllObjects];
    
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"=== 压缩质量不合格报告 ===\n"];
    [report appendFormat:@"检测目录：%@\n", [_inputDir lastPathComponent]];
    [report appendFormat:@"图片数量：%lu\n", (unsigned long)imageFiles.count];
    [report appendFormat:@"质量阈值 - 最小:%.0fKB 最大:%.0fKB 最小长边:%ld 最大长边:%ld\n",
     minCompressedSizeKB, maxCompressedSizeKB, (long)minLongEdge, (long)maxLongEdge];
    [report appendString:@"\n"];
    
    for (NSString *file in imageFiles) {
        NSString *inputPath = [_inputDir stringByAppendingPathComponent:file];
        NSString *outputFilePath = [_outputDir stringByAppendingPathComponent:file];
        NSString *relativeOutputPath = [@"compressed" stringByAppendingPathComponent:file];
        
        NSDictionary *attrs = [fm attributesOfItemAtPath:inputPath error:nil];
        NSInteger originalSize = [attrs[NSFileSize] integerValue];
        _totalOriginalSizeKB += originalSize / 1024.0;
        
        UIImage *image = [UIImage imageWithContentsOfFile:inputPath];
        if (!image) {
            continue;
        }
        
        CGSize originalSizeValue = image.size;
        NSInteger originalWidth = (NSInteger)(originalSizeValue.width * image.scale);
        NSInteger originalHeight = (NSInteger)(originalSizeValue.height * image.scale);
        NSInteger originalMaxEdge = MAX(originalWidth, originalHeight);
        
        CGFloat originalSizeKB = (CGFloat)originalSize / 1024.0;
        BOOL originalValid = (originalSizeKB >= minCompressedSizeKB && originalMaxEdge >= minLongEdge);
        
        NSError *compressError = nil;
        ImageCompressionManager *manager = [ImageCompressionManager sharedManager];
        NSData *compressedData = [manager compressImage:image error:&compressError];
        
        if (compressedData) {
            NSInteger compressedSize = [compressedData length];
            CGFloat compressedSizeKB = (CGFloat)compressedSize / 1024.0;
            _totalCompressedSizeKB += compressedSize / 1024.0;
            
            UIImage *compressedImage = [UIImage imageWithData:compressedData];
            CGSize compressedSizeValue = compressedImage.size;
            NSInteger compressedWidth = (NSInteger)(compressedSizeValue.width * compressedImage.scale);
            NSInteger compressedHeight = (NSInteger)(compressedSizeValue.height * compressedImage.scale);
            NSInteger minCompressedEdge = MIN(compressedWidth, compressedHeight);
            NSInteger maxCompressedEdge = MAX(compressedWidth, compressedHeight);
            
            BOOL sizeInRange = (compressedSizeKB >= minCompressedSizeKB && compressedSizeKB <= maxCompressedSizeKB);
            BOOL edgeValid = (minCompressedEdge >= minLongEdge && maxCompressedEdge <= maxLongEdge);
            
            if (originalValid && (!sizeInRange || !edgeValid)) {
                // 只有不合格的图片才保存
                [compressedData writeToFile:outputFilePath atomically:YES];
                
                _failedCount++;
                
                CompressionResultItem *item = [[CompressionResultItem alloc] init];
                item.fileName = file;
                item.originalSizeKB = originalSizeKB;
                item.originalWidth = originalWidth;
                item.originalHeight = originalHeight;
                item.compressedSizeKB = compressedSizeKB;
                item.compressedWidth = compressedWidth;
                item.compressedHeight = compressedHeight;
                item.outputPath = relativeOutputPath;
                [_failedItems addObject:item];
                
                [report appendFormat:@"--- %@ ---\n", file];
                [report appendFormat:@"  原始大小：%.2f KB\n", originalSizeKB];
                [report appendFormat:@"  原始宽高：%ld x %ld\n", (long)originalWidth, (long)originalHeight];
                [report appendFormat:@"  压缩后大小：%.2f KB\n", compressedSizeKB];
                [report appendFormat:@"  压缩后宽高：%ld x %ld\n", (long)compressedWidth, (long)compressedHeight];
                [report appendFormat:@"  压缩后路径：%@\n", relativeOutputPath];
                [report appendString:@"\n"];
            }
        }
    }
    
    [report appendString:@"=== 统计汇总 ===\n"];
    [report appendFormat:@"原始总大小：%.2f KB\n", _totalOriginalSizeKB];
    [report appendFormat:@"压缩后总大小：%.2f KB\n", _totalCompressedSizeKB];
    [report appendFormat:@"质量不合格图片数量：%ld\n", (long)_failedCount];
    
    if (_totalOriginalSizeKB > 0) {
        CGFloat overallRatio = (_totalOriginalSizeKB - _totalCompressedSizeKB) / _totalOriginalSizeKB * 100.0;
        [report appendFormat:@"总体压缩率：%.1f%%\n", overallRatio];
    }
    
    [report writeToFile:_reportPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"报告已保存到: %@", _reportPath);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatsLabel];
        [self.tableView reloadData];
        [self hideLoading];
    });
}

@end
