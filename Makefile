# Chen Zhao, Debananda Sarkar, Jared Splinter, Peter Yang
# 2020-12-04
# 
# This make file is for predicting if a reservation is likely to be cancelled by given a hotel booking detail.
# 
# Usage:
# make all

all : doc/hotel_cancellation_predict_report.md

# download data set
data/raw/hotels_dataset.csv : src/getdata.py
	python src/getdata.py --source_url=https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2020/2020-02-11/hotels.csv --target_file=data/raw/hotels_dataset.csv

# preprocess data
data/processed/train_df.csv data/processed/test_df.csv : data/raw/hotels_dataset.csv src/split_dataset_train_test.py
	python src/split_dataset_train_test.py --source_data_file=data/raw/hotels_dataset.csv --train_data_file=data/processed/train_df.csv --test_data_file=data/processed/test_df.csv --test_split_ratio=0.2 --chosen_seed=1

# create exploratory data analysis tables and figures, and write to file
results/numeric_vs_target.svg results/cat_vs_target.svg results/corr_all.svg results/corr_target.svg results/feature_exam.svg results/price_vs_month.svg results/guest_vs_month.svg results/rep_guests_prev_cancel.svg results/missing_summary.csv : data/processed/train_df.csv src/eda_ms2.py
	python src/eda_ms2.py --train=data/processed/train_df.csv --out_dir=results/

# train model and tune hyperparameters

## Below script will take approximately 40 minutes to run!!
results/five_fold_cross_validation_result.csv : data/processed/train_df.csv src/classifier_evaluation.py src/helper_functions.py
	python src/classifier_evaluation.py data/processed/train_df.csv results/five_fold_cross_validation_result.csv --n_cv_folds=5 --chosen_seed=2020 --verbose=True

## Below script will take approximately 2 hours to run!!
results/random_forest_model.sav results/random_forest_tuning_result.csv : data/processed/train_df.csv src/model_tuning.py src/helper_functions.py
	python src/model_tuning.py data/processed/train_df.csv results/ random_forest --n_iter=10 --n_cv_folds=5 --chosen_seed=2020 --verbose=True

## The prediction scripts below use a model file which is not on github due to size issue
## Please run the model_tuning.py script above to generate the model file
results/random_forest_confusion_matrix_test_data.png results/random_forest_precision_recall_curve_test_data.png results/random_forest_score_summary_test_data.csv : data/processed/test_df.csv results/random_forest_model.sav src/predict_cancellation.py src/helper_functions.py
	python src/predict_cancellation.py results/random_forest_model.sav data/processed/test_df.csv --result_path=results/ --model_name=random_forest --dataset_label=test --verbose=False

results/random_forest_confusion_matrix_train_data.png results/random_forest_precision_recall_curve_train_data.png results/random_forest_score_summary_train_data.csv : data/processed/train_df.csv results/random_forest_model.sav src/predict_cancellation.py src/helper_functions.py
	python src/predict_cancellation.py results/random_forest_model.sav data/processed/train_df.csv --result_path=results/ --model_name=random_forest --dataset_label=train --verbose=False

# render final report
doc/hotel_cancellation_predict_report.md : doc/hotel_cancellation_predict_report.Rmd doc/hotels_refs.bib results/numeric_vs_target.svg results/cat_vs_target.svg results/corr_all.svg results/corr_target.svg results/feature_exam.svg results/price_vs_month.svg results/guest_vs_month.svg results/rep_guests_prev_cancel.svg results/missing_summary.csv results/five_fold_cross_validation_result.csv results/random_forest_tuning_result.csv results/random_forest_confusion_matrix_test_data.png results/random_forest_precision_recall_curve_test_data.png results/random_forest_score_summary_test_data.csv results/random_forest_confusion_matrix_train_data.png results/random_forest_precision_recall_curve_train_data.png results/random_forest_score_summary_train_data.csv
	Rscript -e "rmarkdown::render('doc/hotel_cancellation_predict_report.Rmd', output_format = 'github_document')"

clean :
	rm -rf data/raw/hotels_dataset.csv
	rm -rf data/processed/*
	rm -rf results/*
	rm -rf doc/hotel_cancellation_predict_report.md
