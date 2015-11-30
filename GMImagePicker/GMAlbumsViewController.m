//
//  GMAlbumsViewController.m
//  GMPhotoPicker
//
//  Created by Guillermo Muntaner Perelló on 19/09/14.
//  Copyright (c) 2014 Guillermo Muntaner Perelló. All rights reserved.
//

#import "GMImagePickerController.h"
#import "GMAlbumsViewController.h"
#import "GMGridViewCell.h"
#import "GMGridViewController.h"
#import "GMAlbumsViewCell.h"

@import Photos;

@interface GMAlbumsViewController() <PHPhotoLibraryChangeObserver>

@property (strong) NSArray *collectionsFetchResults;
@property (strong) NSArray *collectionsLocalizedTitles;
@property (strong) NSArray *collectionsFetchResultsAssets;
@property (strong) NSArray *collectionsFetchResultsTitles;
@property (nonatomic, weak) GMImagePickerController *picker;
@property (strong) PHCachingImageManager *imageManager;

@end


@implementation GMAlbumsViewController

- (id)init
{
    if (self = [super initWithStyle:UITableViewStylePlain])
    {
        self.preferredContentSize = kPopoverContentSize;
    }
    
    return self;
}

static NSString * const AllPhotosReuseIdentifier = @"AllPhotosCell";
static NSString * const CollectionCellReuseIdentifier = @"CollectionCell";

- (void)accessGranted
{
    self.tableView.tableFooterView = nil;
    self.imageManager = [[PHCachingImageManager alloc] init];
    
    //Fetch PHAssetCollections:
    PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    self.collectionsFetchResults = @[topLevelUserCollections, smartAlbums];
    self.collectionsLocalizedTitles = @[NSLocalizedStringFromTableInBundle(@"picker.table.user-albums-header",  @"GMImagePicker", [NSBundle bundleForClass:GMImagePickerController.class], @"Albums"), NSLocalizedStringFromTableInBundle(@"picker.table.smart-albums-header",  @"GMImagePicker", [NSBundle bundleForClass:GMImagePickerController.class], @"Smart Albums")];
    
    [self updateFetchResults];
    
    //Register for changes
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

- (void)onSettingsButton
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: UIApplicationOpenSettingsURLString]];
}

//TODO: need a wait to customize this
-(void)authorizationWarning
{
    UILabel* label = [UILabel new];
    label.font = [UIFont boldSystemFontOfSize:17];
    label.text = @"This app does not have access to your photos or videos";
    label.textColor = [UIColor grayColor];
    
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    
    NSDictionary* attr1 = @{NSForegroundColorAttributeName : [UIColor grayColor]};
    NSDictionary* attr2 = @{NSForegroundColorAttributeName : [UIColor blueColor]};
    
    NSMutableAttributedString *buttonTitle = [[NSMutableAttributedString alloc] initWithString:@"You can enable access in " attributes:attr1];
    [buttonTitle appendAttributedString:[[NSAttributedString alloc] initWithString:@"Privacy Settings" attributes: attr2]];
    [buttonTitle appendAttributedString:[[NSAttributedString alloc] initWithString:@"." attributes: attr1]];
    
    UIButton* button = [UIButton new];
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    [button setAttributedTitle:buttonTitle forState:UIControlStateNormal];
    [button addTarget:self action:@selector(onSettingsButton) forControlEvents:UIControlEventTouchUpInside];
    
    CGFloat width = self.view.bounds.size.width;
    
	//TODO: Layout
    CGFloat labelHeight = [label sizeThatFits:CGSizeMake(width, 1000)].height;
    CGFloat buttonHeight = [button sizeThatFits:CGSizeMake(width, 1000)].height;
    CGFloat topoffset = 150;
    CGFloat padding = 20;
    
    label.frame = CGRectMake(0, topoffset, width, labelHeight);
    button.frame = CGRectMake(0, topoffset + labelHeight + padding, width, buttonHeight);
    
    UIView* footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, labelHeight + buttonHeight + topoffset + padding)];
    [footer addSubview:label];
    [footer addSubview:button];
    
    self.tableView.tableFooterView = footer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //Navigation bar customization_
    if(self.picker.customNavigationBarPrompt)
    {
        self.navigationItem.prompt = self.picker.customNavigationBarPrompt;
    }
    
    //Table view aspect
    self.tableView.rowHeight = kAlbumRowHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    //Navigation bar items
    //if (self.picker.showsCancelButton)
    {
        self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"picker.navigation.cancel-button",  @"GMImagePicker", [NSBundle bundleForClass:GMImagePickerController.class], @"Cancel")
                                         style:UIBarButtonItemStylePlain
                                        target:self.picker
                                        action:@selector(dismiss:)];
    }
    
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"picker.navigation.done-button",  @"GMImagePicker", [NSBundle bundleForClass:GMImagePickerController.class], @"Done")
                                     style:UIBarButtonItemStyleDone
                                    target:self.picker
                                    action:@selector(finishPickingAssets:)];
    
    self.navigationItem.rightBarButtonItem.enabled = (self.picker.autoDisableDoneButton ? self.picker.selectedAssets.count > 0 : TRUE);
    
    //Bottom toolbar
    self.toolbarItems = self.picker.toolbarItems;
    
    //Title
    if (!self.picker.title)
        self.title = NSLocalizedStringFromTableInBundle(@"picker.navigation.title",  @"GMImagePicker", [NSBundle bundleForClass:GMImagePickerController.class], @"Navigation bar default title");
    else
        self.title = self.picker.title;

    if([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized)
    {
        [self accessGranted];
    }
    else if([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined)
    {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if(status == PHAuthorizationStatusAuthorized)
                [self accessGranted];
            else
                [self authorizationWarning];
        }];
    }
    else
    {
        [self authorizationWarning];
    }
    
}

- (void)dealloc
{
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

-(void)updateFetchResults
{
    //What I do here is fetch both the albums list and the assets of each album.
    //This way I have acces to the number of items in each album, I can load the 3
    //thumbnails directly and I can pass the fetched result to the gridViewController.
    
    self.collectionsFetchResultsAssets=nil;
    self.collectionsFetchResultsTitles=nil;
    
    //Fetch PHAssetCollections:
    PHFetchResult *topLevelUserCollections = [self.collectionsFetchResults objectAtIndex:0];
    PHFetchResult *smartAlbums = [self.collectionsFetchResults objectAtIndex:1];
    
    //All album: Sorted by descending creation date.
    NSMutableArray *allFetchResultArray = [[NSMutableArray alloc] init];
    NSMutableArray *allFetchResultLabel = [[NSMutableArray alloc] init];
    {
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        options.predicate = [NSPredicate predicateWithFormat:@"mediaType in %@", self.picker.mediaTypes];
        options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsWithOptions:options];
        [allFetchResultArray addObject:assetsFetchResult];
        [allFetchResultLabel addObject:NSLocalizedStringFromTableInBundle(@"picker.table.all-photos-label",  @"GMImagePicker", [NSBundle bundleForClass:GMImagePickerController.class], @"All photos")];
    }
    
    //User albums:
    NSMutableArray *userFetchResultArray = [[NSMutableArray alloc] init];
    NSMutableArray *userFetchResultLabel = [[NSMutableArray alloc] init];
    for(PHCollection *collection in topLevelUserCollections)
    {
        if ([collection isKindOfClass:[PHAssetCollection class]])
        {
            PHFetchOptions *options = [[PHFetchOptions alloc] init];
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType in %@", self.picker.mediaTypes];
            PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
            
            //Albums collections are allways PHAssetCollectionType=1 & PHAssetCollectionSubtype=2
            
            PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
            [userFetchResultArray addObject:assetsFetchResult];
            [userFetchResultLabel addObject:collection.localizedTitle];
        }
    }
    
                                  
    //Smart albums: Sorted by descending creation date.
    NSMutableArray *smartFetchResultArray = [[NSMutableArray alloc] init];
    NSMutableArray *smartFetchResultLabel = [[NSMutableArray alloc] init];
    for(PHCollection *collection in smartAlbums)
    {
        if ([collection isKindOfClass:[PHAssetCollection class]])
        {
            PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
            
            //Smart collections are PHAssetCollectionType=2;
            if(self.picker.customSmartCollections && [self.picker.customSmartCollections containsObject:@(assetCollection.assetCollectionSubtype)])
            {
                PHFetchOptions *options = [[PHFetchOptions alloc] init];
                options.predicate = [NSPredicate predicateWithFormat:@"mediaType in %@", self.picker.mediaTypes];
                options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
                
                PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
                if(assetsFetchResult.count>0)
                {
                    [smartFetchResultArray addObject:assetsFetchResult];
                    [smartFetchResultLabel addObject:collection.localizedTitle];
                }
            }
        }
    }
    
    self.collectionsFetchResultsAssets= @[allFetchResultArray,userFetchResultArray,smartFetchResultArray];
    self.collectionsFetchResultsTitles= @[allFetchResultLabel,userFetchResultLabel,smartFetchResultLabel];
}


#pragma mark - Accessors

- (GMImagePickerController *)picker
{
    return (GMImagePickerController *)self.navigationController.parentViewController;
}


#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.collectionsFetchResultsAssets.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    PHFetchResult *fetchResult = self.collectionsFetchResultsAssets[section];
    return fetchResult.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    GMAlbumsViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[GMAlbumsViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    // Increment the cell's tag
    NSInteger currentTag = cell.tag + 1;
    cell.tag = currentTag;

    //Set the label
    cell.textLabel.text = (self.collectionsFetchResultsTitles[indexPath.section])[indexPath.row];
    
    //Retrieve the pre-fetched assets for this album:
    PHFetchResult *assetsFetchResult = (self.collectionsFetchResultsAssets[indexPath.section])[indexPath.row];
    
    //Display the number of assets
    if(self.picker.displayAlbumsNumberOfAssets)
    {
        cell.detailTextLabel.text = [self tableCellSubtitle:assetsFetchResult];
    }
    
    //Set the 3 images (if exists):
    if([assetsFetchResult count]>0)
    {
        CGFloat scale = [UIScreen mainScreen].scale;
        
        //Compute the thumbnail pixel size:
        CGSize tableCellThumbnailSize1 = CGSizeMake(kAlbumThumbnailSize1.width*scale, kAlbumThumbnailSize1.height*scale);
        PHAsset *asset = assetsFetchResult[0];
        [cell setVideoLayout:(asset.mediaType==PHAssetMediaTypeVideo)];
        [self.imageManager requestImageForAsset:asset
                                     targetSize:tableCellThumbnailSize1
                                    contentMode:PHImageContentModeAspectFill
                                        options:nil
                                  resultHandler:^(UIImage *result, NSDictionary *info)
         {
             if (cell.tag == currentTag)
             {
                 cell.imageView1.image = result;
             }
         }];
        
        //Second & third images:
        // TO DO: Only preload the 3pixels height visible frame!
        if([assetsFetchResult count]>1)
        {
            //Compute the thumbnail pixel size:
            CGSize tableCellThumbnailSize2 = CGSizeMake(kAlbumThumbnailSize2.width*scale, kAlbumThumbnailSize2.height*scale);
            PHAsset *asset = assetsFetchResult[1];
            [self.imageManager requestImageForAsset:asset
                                         targetSize:tableCellThumbnailSize2
                                        contentMode:PHImageContentModeAspectFill
                                            options:nil
                                      resultHandler:^(UIImage *result, NSDictionary *info)
             {
                 if (cell.tag == currentTag)
                 {
                     cell.imageView2.image = result;
                 }
             }];
        }
        else
        {
            cell.imageView2.image = nil;
        }
        if([assetsFetchResult count]>2)
        {
            CGSize tableCellThumbnailSize3 = CGSizeMake(kAlbumThumbnailSize3.width*scale, kAlbumThumbnailSize3.height*scale);
            PHAsset *asset = assetsFetchResult[2];
            [self.imageManager requestImageForAsset:asset
                                         targetSize:tableCellThumbnailSize3
                                        contentMode:PHImageContentModeAspectFill
                                            options:nil
                                      resultHandler:^(UIImage *result, NSDictionary *info)
             {
                 if (cell.tag == currentTag)
                 {
                     cell.imageView3.image = result;
                 }
             }];
        }
        else
        {
            cell.imageView3.image = nil;
        }
    }
    else
    {
        [cell setVideoLayout:NO];
        cell.imageView3.image = [UIImage imageNamed:@"EmptyFolder"];
        cell.imageView2.image = [UIImage imageNamed:@"EmptyFolder"];
        cell.imageView1.image = [UIImage imageNamed:@"EmptyFolder"];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    //Init the GMGridViewController
    GMGridViewController *gridViewController = [[GMGridViewController alloc] initWithPicker:[self picker]];
    //Set the title
    gridViewController.title = cell.textLabel.text;
    //Use the prefetched assets!
    gridViewController.assetsFetchResults = [[_collectionsFetchResultsAssets objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    //Push GMGridViewController
    [self.navigationController pushViewController:gridViewController animated:YES];
}

#pragma mark  Header

-(void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    
    //Here you can customize header views!
    header.textLabel.font = [UIFont systemFontOfSize:14.0f]; //Set font to "normal" style (default is bold) and to 14 pts.
    //header.textLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    //header.textLabel.textColor = [UIColor orangeColor];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    //Tip: Returning nil hides the section header!
    
    NSString *title = nil;
    if (section > 0)
    {
        //Only show title for non-empty sections:
        PHFetchResult *fetchResult = self.collectionsFetchResultsAssets[section];
        if( fetchResult.count >0)
        {
            title = self.collectionsLocalizedTitles[section - 1];
        }
    }
    return title;
}


#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    // Call might come on any background queue. Re-dispatch to the main queue to handle it.
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSMutableArray *updatedCollectionsFetchResults = nil;
        
        for (PHFetchResult *collectionsFetchResult in self.collectionsFetchResults) {
            PHFetchResultChangeDetails *changeDetails = [changeInstance changeDetailsForFetchResult:collectionsFetchResult];
            if (changeDetails) {
                if (!updatedCollectionsFetchResults) {
                    updatedCollectionsFetchResults = [self.collectionsFetchResults mutableCopy];
                }
                [updatedCollectionsFetchResults replaceObjectAtIndex:[self.collectionsFetchResults indexOfObject:collectionsFetchResult] withObject:[changeDetails fetchResultAfterChanges]];
            }
        }
        
        //This only affects to changes in albums level (add/remove/edit album)
        if (updatedCollectionsFetchResults)
        {
            self.collectionsFetchResults = updatedCollectionsFetchResults;
        }
        
        //However, we want to update if photos are added, so the counts of items & thumbnails are updated too.
        //Maybe some checks could be done here , but for now is OKey.
        [self updateFetchResults];
        [self.tableView reloadData];
        
    });
}



#pragma mark - Cell Subtitle

- (NSString *)tableCellSubtitle:(PHFetchResult*)assetsFetchResult
{
    //Just return the number of assets. Album app does this:
    return [NSString stringWithFormat:@"%ld", (long)[assetsFetchResult count]];
}



@end