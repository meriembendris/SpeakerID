#!/bin/bash


tool=/storage/raid1/homedirs/meriem.bendris/tools
audio=/storage/raid1/homedirs/meriem.bendris/work/adnvideo/speakerID/BFMTV_BFMStory_2011-11-02_175800.wav
show=`basename $audio .wav`
outputdir=mon_test/
mkdir $outputdir
LOCALCLASSPATH=$tool/LIUM_SpkDiarization.jar

mem=1G

pmsgmm=/storage/raid1/homedirs/meriem.bendris/work/adnvideo/speakerID/models/sms.gmms
sgmm=/storage/raid1/homedirs/meriem.bendris/work/adnvideo/speakerID/models/s.gmms
ggmm=/storage/raid1/homedirs/meriem.bendris/work/adnvideo/speakerID/models/gender.gmms
ubm=/storage/raid1/homedirs/meriem.bendris/work/adnvideo/speakerID/models/ubm.gmm



features=$outputdir/%s.mfcc
fDescStart="audio16kHz2sphinx,1:1:0:0:0:0,13,0:0:0"
fDesc="sphinx,1:1:0:0:0:0,13,0:0:0"
fDescD="sphinx,1:3:2:0:0:0,13,0:0:0:0"
fDescLast="sphinx,1:3:2:0:0:0,13,1:1:0:0"
fDescCLR="sphinx,1:3:2:0:0:0,13,1:1:300:4"



#Extract MFCC from wav
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.Wave2FeatureSet --help --fInputMask=$audio --fInputDesc=$fDescStart --fOutputMask=$features --fOutputDesc=$fDesc $show

# initial segmentation
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSegInit   --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$uem --sOutputMask=./$outputdir/%s.i.seg  $show


#GLR based segmentation, make small segments
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSeg   --kind=FULL --sMethod=GLR  --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/%s.i.seg --sOutputMask=./$outputdir/%s.s.seg  $show


# Linear clustering
l=2
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust    --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/%s.s.seg --sOutputMask=./$outputdir/%s.l.seg --cMethod=l --cThr=$l $show


# Hierarchical clustering
h=3
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust    --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/%s.l.seg --sOutputMask=./$outputdir/%s.h.$h.seg --cMethod=h --cThr=$h $show






#*************************************
#************* TRAIN GMM *************
#*************************************
#Initialize GMM
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainInit   --help --nbComp=8 --kind=DIAG --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/%s.h.$h.seg --tOutputMask=./$outputdir/%s.init.gmms $show

# EM computation
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainEM   --help  --nbComp=8 --kind=DIAG --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/%s.h.$h.seg --tOutputMask=./$outputdir/%s.gmms  --tInputMask=./$outputdir/%s.init.gmms  $show 

#Viterbi decoding
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode    --help --fInputMask=${features} --fInputDesc=$fDesc --sInputMask=./$outputdir/%s.h.$h.seg --sOutputMask=./$outputdir/%s.d.$h.seg --dPenality=250  --tInputMask=$outputdir/%s.gmms $show



#*************************************************************
#************* Speech/Music/Silence segmentation *************
#*************************************************************

# Apply the PMS gmm
pmsseg=$outputdir/$show.pms.seg
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode  --help  --fInputDesc=$fDescD --fInputMask=$features --sInputMask=./$outputdir/%s.i.seg --sOutputMask=$pmsseg --dPenality=10,10,50 --tInputMask=$pmsgmm $show

# Filter the segmentation according pms segmentation (delete segments in the cluster j)
fltseg=$outputdir/$show.flt.$h.seg
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SFilter --help  --fInputDesc=$fDescD --fInputMask=$features --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 --sFilterClusterName=j --fltSegPadding=25 --sFilterMask=$pmsseg --sInputMask=./$outputdir/%s.d.$h.seg --sOutputMask=$fltseg $show


#*************************************************************
#************* Gender detectrion *****************************
#*************************************************************

# Set gender and bandwith
gseg=$outputdir/$show.g.$h.seg
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MScore --help  --sGender --sByCluster --fInputDesc=$fDescLast --fInputMask=$features --sInputMask=$fltseg --sOutputMask=$gseg --tInputMask=$ggmm $show


#*************************************************************
#************* Speaker ID ************************************
#*************************************************************

features_test=$outputdir/François_REBSAMEN_Autre.mfcc
features_train=$outputdir/François_REBSAMEN_Plateau.mfcc

show_train=François_REBSAMEN_Plateau
show_test=François_REBSAMEN_Autre
audio_train=/storage/raid1/homedirs/meriem.bendris/work/adnvideo/speakerID/François_REBSAMEN_Plateau.wav
audio_test=/storage/raid1/homedirs/meriem.bendris/work/adnvideo/speakerID/François_REBSAMEN_Autre.wav

# Extract features and do segmentation 

	#Extract MFCC from wav
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.Wave2FeatureSet --help --fInputMask=$audio_train --fInputDesc=$fDescStart --fOutputMask=$features_train --fOutputDesc=$fDesc $show_train
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.Wave2FeatureSet --help --fInputMask=$audio_test --fInputDesc=$fDescStart --fOutputMask=$features_test --fOutputDesc=$fDesc $show_test

	# initial segmentation
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSegInit   --help --fInputMask=$features_train --fInputDesc=$fDesc --sInputMask=$uem --sOutputMask=./$outputdir/$show_train.i.seg  $show_train
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSegInit   --help --fInputMask=$features_test --fInputDesc=$fDesc --sInputMask=$uem --sOutputMask=./$outputdir/$show_test.i.seg  $show_test


	#GLR based segmentation, make small segments
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSeg   --kind=FULL --sMethod=GLR  --help --fInputMask=$features_train --fInputDesc=$fDesc --sInputMask=./$outputdir/$show_train.i.seg --sOutputMask=./$outputdir/$show_train.s.seg  $show_train
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSeg   --kind=FULL --sMethod=GLR  --help --fInputMask=$features_test  --fInputDesc=$fDesc --sInputMask=./$outputdir/$show_test.i.seg --sOutputMask=./$outputdir/$show_test.s.seg  $show_test


	# Linear clustering
	l=2
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust    --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/$show_train.s.seg --sOutputMask=./$outputdir/$show_train.l.seg --cMethod=l --cThr=$l $show_train
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust    --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/$show_test.s.seg  --sOutputMask=./$outputdir/$show_test.l.seg --cMethod=l --cThr=$l $show_test


	# Hierarchical clustering
	h=3
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust    --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/$show_train.l.seg --sOutputMask=./$outputdir/$show_train.h.$h.seg --cMethod=h --cThr=$h $show_train
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust    --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=./$outputdir/$show_test.l.seg --sOutputMask=./$outputdir/$show_test.h.$h.seg --cMethod=h --cThr=$h $show_test

	# Apply the PMS gmm
	pmsseg_train=$outputdir/$show_train.pms.seg
	pmsseg_test=$outputdir/$show_test.pms.seg
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode  --help  --fInputDesc=$fDescD --fInputMask=$features_train --sInputMask=./$outputdir/$show_train.i.seg --sOutputMask=$pmsseg_train --dPenality=10,10,50 --tInputMask=$pmsgmm $show_train
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode  --help  --fInputDesc=$fDescD --fInputMask=$features_test --sInputMask=./$outputdir/$show_test.i.seg --sOutputMask=$pmsseg_test --dPenality=10,10,50 --tInputMask=$pmsgmm $show_test

	# Filter the segmentation according pms segmentation (delete segments in the cluster j)
	fltseg_train=$outputdir/$show_train.flt.$h.seg
	fltseg_test=$outputdir/$show_test.flt.$h.seg
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SFilter --help  --fInputDesc=$fDescD --fInputMask=$features_train --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 --sFilterClusterName=j --fltSegPadding=25 --sFilterMask=$pmsseg_train --sInputMask=./$outputdir/$show_train.h.$h.seg --sOutputMask=$fltseg_train $show_train
	java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SFilter --help  --fInputDesc=$fDescD --fInputMask=$features_test --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 --sFilterClusterName=j --fltSegPadding=25 --sFilterMask=$pmsseg_test --sInputMask=./$outputdir/$show_test.h.$h.seg --sOutputMask=$fltseg_test $show_test


# Learn








#initialize gmm to ubm 
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainInit --help --sInputMask=$outputdir/$show_train.flt.$h.seg --fInputMask=$audio_train --fInputDesc=$fDescStart  --emInitMethod=copy --tInputMask=$ubm --tOutputMask=$outputdir/$show_train.init.gmm $show_train
 
#train (MAP adaptation, mean only) of each speaker, the diarization file describes the training data of each speaker.
java -Xmx$mem -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainMAP --help  --sInputMask=$outputdir/$show_train.flt.$h.seg --fInputMask=$audio_train --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,1:1:300:4  --tInputMask=$outputdir/$show_train.init.gmm --emCtrl=1,5,0.01 --varCtrl=0.01,10.0 --tOutputMask=$outputdir/$show_train.gmm $show_train

# Apply


java -Xmx$mem -classpath  "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.Identification --help --sInputMask=$outputdir/$show_test.flt.$h.seg --fInputMask=$features_test --sOutputMask=$outputdir/$show_test.ident.seg --fInputDesc=$fDescLast --tInputMask=$outputdir/$show_train.gmm  --sTop=5,$ubm  --sSetLabel=add $show_test

