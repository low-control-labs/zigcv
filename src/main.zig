pub const asyncarray = @import("asyncarray.zig");
pub const core = @import("core.zig");
pub const calib3d = @import("calib3d.zig");
pub const dnn = @import("dnn.zig");
pub const features2d = @import("features2d.zig");
pub const highgui = @import("highgui.zig");
pub const objdetect = @import("objdetect.zig");
pub const imgcodecs = @import("imgcodecs.zig");
pub const imgproc = @import("imgproc.zig");
pub const ColorConversionCode = @import("imgproc/color_codes.zig").ColorConversionCode;
pub const photo = @import("photo.zig");
pub const svd = @import("svd.zig");
pub const version = @import("version.zig");
pub const videoio = @import("videoio.zig");
pub const video = @import("video.zig");

pub const c_api = @import("c");
pub const utils = @import("utils.zig");

test {
    @import("std").testing.refAllDecls(@This());
}

// usingnamespace was removed from the language; the flat `cv.*` namespace is re-exported explicitly.

// asyncarray
pub const AsyncArray = asyncarray.AsyncArray;

// core
pub const Mat = core.Mat;
pub const Mats = core.Mats;
pub const BorderType = core.BorderType;
pub const NormType = core.NormType;
pub const Point = core.Point;
pub const PointVector = core.PointVector;
pub const PointsVector = core.PointsVector;
pub const Point2f = core.Point2f;
pub const Point2fVector = core.Point2fVector;
pub const Points2fVector = core.Points2fVector;
pub const Point3f = core.Point3f;
pub const Point3fVector = core.Point3fVector;
pub const Points3fVector = core.Points3fVector;
pub const Scalar = core.Scalar;
pub const Color = core.Color;
pub const KeyPoint = core.KeyPoint;
pub const KeyPoints = core.KeyPoints;
pub const Rect = core.Rect;
pub const Rects = core.Rects;
pub const RotatedRect = core.RotatedRect;
pub const Size = core.Size;
pub const RNG = core.RNG;
pub const STDVector = core.STDVector;
pub const TermCriteria = core.TermCriteria;
pub const getCVTickCount = core.getCVTickCount;
pub const getTickFrequency = core.getTickFrequency;

// calib3d
pub const CalibFlags = calib3d.CalibFlags;
pub const CalibCBFlags = calib3d.CalibCBFlags;
pub const Fisheye = calib3d.Fisheye;
pub const initUndistortRectifyMap = calib3d.initUndistortRectifyMap;
pub const getOptimalNewCameraMatrixWithParams = calib3d.getOptimalNewCameraMatrixWithParams;
pub const calibrateCamera = calib3d.calibrateCamera;
pub const undistort = calib3d.undistort;
pub const undistortPoints = calib3d.undistortPoints;
pub const findChessboardCorners = calib3d.findChessboardCorners;
pub const findChessboardCornersSB = calib3d.findChessboardCornersSB;
pub const findChessboardCornersSBWithMeta = calib3d.findChessboardCornersSBWithMeta;
pub const drawChessboardCorners = calib3d.drawChessboardCorners;
pub const estimateAffinePartial2D = calib3d.estimateAffinePartial2D;
pub const estimateAffine2D = calib3d.estimateAffine2D;
pub const estimateAffine2DMethod = calib3d.estimateAffine2DMethod;
pub const estimateAffine2DWithParams = calib3d.estimateAffine2DWithParams;

// dnn
pub const Net = dnn.Net;
pub const Blob = dnn.Blob;
pub const Layer = dnn.Layer;
pub const nmsBoxes = dnn.nmsBoxes;
pub const nmsBoxesWithParams = dnn.nmsBoxesWithParams;

// features2d
pub const AKAZE = features2d.AKAZE;
pub const AgastFeatureDetector = features2d.AgastFeatureDetector;
pub const BRISK = features2d.BRISK;
pub const FastFeatureDetector = features2d.FastFeatureDetector;
pub const GFTTDetector = features2d.GFTTDetector;
pub const KAZE = features2d.KAZE;
pub const MSER = features2d.MSER;
pub const ORB = features2d.ORB;
pub const SIFT = features2d.SIFT;
pub const SimpleBlobDetector = features2d.SimpleBlobDetector;
pub const BFMatcher = features2d.BFMatcher;
pub const FlannBasedMatcher = features2d.FlannBasedMatcher;
pub const DrawMatchesFlag = features2d.DrawMatchesFlag;
pub const drawKeyPoints = features2d.drawKeyPoints;
pub const drawMatches = features2d.drawMatches;
pub const DMatch = features2d.DMatch;

// highgui
pub const Window = highgui.Window;

// objdetect
pub const CascadeClassifier = objdetect.CascadeClassifier;
pub const HOGDescriptor = objdetect.HOGDescriptor;
pub const groupRectangles = objdetect.groupRectangles;
pub const QRCodeDetector = objdetect.QRCodeDetector;

// imgcodecs
pub const IMReadFlag = imgcodecs.IMReadFlag;
pub const IMWriteFlag = imgcodecs.IMWriteFlag;
pub const FileExt = imgcodecs.FileExt;
pub const IMWriteParam = imgcodecs.IMWriteParam;
pub const imRead = imgcodecs.imRead;
pub const imWrite = imgcodecs.imWrite;
pub const imWriteWithParams = imgcodecs.imWriteWithParams;
pub const imDecode = imgcodecs.imDecode;
pub const imEncode = imgcodecs.imEncode;
pub const imEncodeWithParams = imgcodecs.imEncodeWithParams;

// imgproc
pub const ConnectedComponentsAlgorithmType = imgproc.ConnectedComponentsAlgorithmType;
pub const ConnectedComponentsType = imgproc.ConnectedComponentsType;
pub const MorphType = imgproc.MorphType;
pub const HoughMode = imgproc.HoughMode;
pub const GrabCutMode = imgproc.GrabCutMode;
pub const LineType = imgproc.LineType;
pub const HersheyFont = imgproc.HersheyFont;
pub const InterpolationFlag = imgproc.InterpolationFlag;
pub const ColormapType = imgproc.ColormapType;
pub const HomographyMethod = imgproc.HomographyMethod;
pub const DistanceType = imgproc.DistanceType;
pub const DistanceTransformLabelType = imgproc.DistanceTransformLabelType;
pub const DistanceTransformMask = imgproc.DistanceTransformMask;
pub const ThresholdType = imgproc.ThresholdType;
pub const AdaptiveThresholdType = imgproc.AdaptiveThresholdType;
pub const RetrievalMode = imgproc.RetrievalMode;
pub const ContourApproximationMode = imgproc.ContourApproximationMode;
pub const MorphShape = imgproc.MorphShape;
pub const TemplateMatchMode = imgproc.TemplateMatchMode;
pub const HistCompMethod = imgproc.HistCompMethod;
pub const CLAHE = imgproc.CLAHE;
pub const arcLength = imgproc.arcLength;
pub const approxPolyDP = imgproc.approxPolyDP;
pub const cvtColor = imgproc.cvtColor;
pub const equalizeHist = imgproc.equalizeHist;
pub const calcHist = imgproc.calcHist;
pub const compareHist = imgproc.compareHist;
pub const calcBackProject = imgproc.calcBackProject;
pub const convexHull = imgproc.convexHull;
pub const convexityDefects = imgproc.convexityDefects;
pub const bilateralFilter = imgproc.bilateralFilter;
pub const blur = imgproc.blur;
pub const boxFilter = imgproc.boxFilter;
pub const sqBoxFilter = imgproc.sqBoxFilter;
pub const dilate = imgproc.dilate;
pub const dilateWithParams = imgproc.dilateWithParams;
pub const distanceTransform = imgproc.distanceTransform;
pub const erode = imgproc.erode;
pub const erodeWithParams = imgproc.erodeWithParams;
pub const matchTemplate = imgproc.matchTemplate;
pub const moments = imgproc.moments;
pub const pyrDown = imgproc.pyrDown;
pub const pyrUp = imgproc.pyrUp;
pub const boundingRect = imgproc.boundingRect;
pub const boxPoints = imgproc.boxPoints;
pub const contourArea = imgproc.contourArea;
pub const minAreaRect = imgproc.minAreaRect;
pub const fitEllipse = imgproc.fitEllipse;
pub const minEnclosingCircle = imgproc.minEnclosingCircle;
pub const findContours = imgproc.findContours;
pub const findContoursWithParams = imgproc.findContoursWithParams;
pub const pointPolygonTest = imgproc.pointPolygonTest;
pub const connectedComponents = imgproc.connectedComponents;
pub const connectedComponentsWithParams = imgproc.connectedComponentsWithParams;
pub const connectedComponentsWithStats = imgproc.connectedComponentsWithStats;
pub const connectedComponentsWithStatsWithParams = imgproc.connectedComponentsWithStatsWithParams;
pub const gaussianBlur = imgproc.gaussianBlur;
pub const getGaussianKernel = imgproc.getGaussianKernel;
pub const getGaussianKernelWithParams = imgproc.getGaussianKernelWithParams;
pub const laplacian = imgproc.laplacian;
pub const scharr = imgproc.scharr;
pub const getStructuringElement = imgproc.getStructuringElement;
pub const morphologyDefaultBorderValue = imgproc.morphologyDefaultBorderValue;
pub const morphologyEx = imgproc.morphologyEx;
pub const morphologyExWithParams = imgproc.morphologyExWithParams;
pub const medianBlur = imgproc.medianBlur;
pub const canny = imgproc.canny;
pub const cornerSubPix = imgproc.cornerSubPix;
pub const goodFeaturesToTrack = imgproc.goodFeaturesToTrack;
pub const grabCut = imgproc.grabCut;
pub const houghCircles = imgproc.houghCircles;
pub const houghCirclesWithParams = imgproc.houghCirclesWithParams;
pub const houghLines = imgproc.houghLines;
pub const houghLinesP = imgproc.houghLinesP;
pub const houghLinesPWithParams = imgproc.houghLinesPWithParams;
pub const houghLinesPointSet = imgproc.houghLinesPointSet;
pub const integral = imgproc.integral;
pub const threshold = imgproc.threshold;
pub const adaptiveThreshold = imgproc.adaptiveThreshold;
pub const arrowedLine = imgproc.arrowedLine;
pub const circle = imgproc.circle;
pub const circleWithParams = imgproc.circleWithParams;
pub const ellipse = imgproc.ellipse;
pub const ellipseWithParams = imgproc.ellipseWithParams;
pub const line = imgproc.line;
pub const rectangle = imgproc.rectangle;
pub const rectangleWithParams = imgproc.rectangleWithParams;
pub const fillPoly = imgproc.fillPoly;
pub const fillPolyWithParams = imgproc.fillPolyWithParams;
pub const polylines = imgproc.polylines;
pub const getTextSize = imgproc.getTextSize;
pub const getTextSizeWithBaseline = imgproc.getTextSizeWithBaseline;
pub const putText = imgproc.putText;
pub const putTextWithParams = imgproc.putTextWithParams;
pub const resize = imgproc.resize;
pub const getRectSubPix = imgproc.getRectSubPix;
pub const getRotationMatrix2D = imgproc.getRotationMatrix2D;
pub const warpAffine = imgproc.warpAffine;
pub const warpAffineWithParams = imgproc.warpAffineWithParams;
pub const warpPerspective = imgproc.warpPerspective;
pub const warpPerspectiveWithParams = imgproc.warpPerspectiveWithParams;
pub const watershed = imgproc.watershed;
pub const applyColorMap = imgproc.applyColorMap;
pub const applyCustomColorMap = imgproc.applyCustomColorMap;
pub const getPerspectiveTransform = imgproc.getPerspectiveTransform;
pub const getPerspectiveTransform2f = imgproc.getPerspectiveTransform2f;
pub const getAffineTransform = imgproc.getAffineTransform;
pub const getAffineTransform2f = imgproc.getAffineTransform2f;
pub const findHomography = imgproc.findHomography;
pub const drawContours = imgproc.drawContours;
pub const drawContoursWithParams = imgproc.drawContoursWithParams;
pub const sobel = imgproc.sobel;
pub const spatialGradient = imgproc.spatialGradient;
pub const remap = imgproc.remap;
pub const filter2D = imgproc.filter2D;
pub const sepFilter2D = imgproc.sepFilter2D;
pub const logPolar = imgproc.logPolar;
pub const fitLine = imgproc.fitLine;
pub const linearPolar = imgproc.linearPolar;
pub const clipLine = imgproc.clipLine;
pub const invertAffineTransform = imgproc.invertAffineTransform;
pub const phaseCorrelate = imgproc.phaseCorrelate;
pub const accumulate = imgproc.accumulate;
pub const accumulateWithMask = imgproc.accumulateWithMask;
pub const accumulateSquare = imgproc.accumulateSquare;
pub const accumulateSquareWithMask = imgproc.accumulateSquareWithMask;
pub const accumulateProduct = imgproc.accumulateProduct;
pub const accumulateProductWithMask = imgproc.accumulateProductWithMask;
pub const accumulatedWeighted = imgproc.accumulatedWeighted;
pub const accumulatedWeightedWithMask = imgproc.accumulatedWeightedWithMask;

// photo
pub const SeamlessCloneFlag = photo.SeamlessCloneFlag;
pub const EdgeFilter = photo.EdgeFilter;
pub const colorChange = photo.colorChange;
pub const seamlessClone = photo.seamlessClone;
pub const illuminationChange = photo.illuminationChange;
pub const textureFlattening = photo.textureFlattening;
pub const fastNlMeansDenoisingColoredMulti = photo.fastNlMeansDenoisingColoredMulti;
pub const fastNlMeansDenoisingColoredMultiWithParams = photo.fastNlMeansDenoisingColoredMultiWithParams;
pub const fastNlMeansDenoising = photo.fastNlMeansDenoising;
pub const fastNlMeansDenoisingWithParams = photo.fastNlMeansDenoisingWithParams;
pub const fastNlMeansDenoisingColored = photo.fastNlMeansDenoisingColored;
pub const fastNlMeansDenoisingColoredWithParams = photo.fastNlMeansDenoisingColoredWithParams;
pub const MergeMertens = photo.MergeMertens;
pub const AlignMTB = photo.AlignMTB;
pub const detailEnhance = photo.detailEnhance;
pub const edgePreservingFilter = photo.edgePreservingFilter;
pub const pencilSketch = photo.pencilSketch;
pub const stylization = photo.stylization;

// svd
pub const svdCompute = svd.svdCompute;

// version
pub const openCVVersion = version.openCVVersion;

// videoio
pub const VideoCapture = videoio.VideoCapture;
pub const VideoWriter = videoio.VideoWriter;

// video
pub const Motion = video.Motion;
pub const BackgroundSubtractorKNN = video.BackgroundSubtractorKNN;
pub const CalcOpticalFlow = video.CalcOpticalFlow;
pub const findTransformECC = video.findTransformECC;
pub const Tracker = video.Tracker;
pub const TrackerMIL = video.TrackerMIL;
