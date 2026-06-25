import os
from pathlib import Path
from .rule import MyRule, RuleSet, Parameter
from .common import VennFiles
from .shap import ShapSet

class Logistic(MyRule):
    def __init__(self, **kwargs):
        self.script = "model_logistic.R"
        self.args = ["{input.in_mat}", "{input.in_map}", "{input.in_gene}", "{output.forest}", "{output.out_gene}",
                     "{params.top_deg}", "{params.in_type}", "{params.confirm_file}", "{params.seed}", "{params.is_beta}", "{output.model_rds_path}"]

class SVM(MyRule):
    def __init__(self,  **kwargs):
        self.script = "model_svm.R"
        self.args = ["{input.in_mat}", "{input.in_map}", "{input.in_gene}", "{output.error}", "{output.accuracy}", "{output.out_gene}", "{output.imp}", "{params.threads}", "{params.in_type}", "{params.confirm_file}", "{params.seed}", "{output.model_rds_path}"]

class Lasso(MyRule):
    def __init__(self,  **kwargs):
        self.script = "model_lasso.R"
        self.args = ["{input.in_mat}", "{input.in_map}", "{input.in_gene}", "{output.lasso_lambda}", "{output.cv}", "{output.out_gene}", "{output.coef}", "{params.in_type}", "{params.confirm_file}", "{params.seed}", "{output.model_rds_path}"]

class RF(MyRule):
    def __init__(self,  **kwarg):
        self.script = "model_randomForest.R"
        self.args = ["{input.in_mat}", "{input.in_map}", "{input.in_gene}", "{output.rfplot}", "{output.imp}", "{output.impplot}", "{output.rfcv}",
                     "{params.in_type}", "{params.confirm_file}", "{params.seed}", "{output.errplot}", "{output.out_gene}", "{params.top}", "{output.model_rds_path}"]

class RF_select(MyRule):
    def __init__(self, **kwargs):
        self.script = "model_randomforest_selected.R"
        self.args = ["{input.in_imp}", "{input.in_rfcv}", "{output.errplot}", "{output.out_gene}", "{params.top}", "{params.confirm_file}"]

class Gbm(MyRule):
    def __init__(self, **kwargs):
        self.script = "model_gbm.R"
        self.args = ["{input.in_mat}", "{input.in_map}", "{input.in_gene}", "{output.verify}", "{output.imp}", "{output.impplot}", "{output.out_gene}", "{params.top}", "{params.in_type}", "{params.confirm_file}", "{params.seed}", "{output.model_rds_path}"]

class Xgb(MyRule):
    def __init__(self, **kwargs):
        self.script = "model_xgboost.R"
        self.args = ["{input.in_mat}", "{input.in_map}", "{input.in_gene}", "{output.imp}", "{output.impplot}", "{output.out_gene}", "{params.threads}", "{params.in_type}", "{params.confirm_file}", "{params.seed}", "{params.xgb_top}", "{output.model_rds_path}"]

class CompareModel(MyRule):
    def __init__(self, **kwargs):
        self.script = "model_compare.R"
        self.args = ["{input.in_mat}", "{input.in_map}", "{input.in_gene}", "{output.roc_pdf}", "{output.result_csv}",
                     "{output.best_model_rds}", "{output.best_model_name}", "{params.model_names}", "{params.confirm_file}",
                     "{params.seed}", "{params.nthreads}"]

class RandomForest(RuleSet):
    def __init__(self, config, name, **kwarg):
        super().__init__(config)
        self._params_key = {"in_mat", "in_map", "in_gene", "in_type"}

        rf = RF(
            confirm_file=self.confirm_file,
            rfplot=Path("output", "4-randomForest.pdf"),
            imp=Path("output", "4-importance.csv"),
            impplot=Path("output", "4-importance.pdf"),
            rfcv=Path("output", "4-rfcv_mean.csv"),
            seed=config[name]["seed"],
            errplot=Path("output", "4-Cross-validation-error_plot.pdf"),
            out_gene=Path("output", "4-randomforest_genes.csv"),
            top=config[name]["rf_top"],
            model_rds_path=Path("output", "4-randomForest_model.rds")
        )
        self.append(rf, {"in_mat", "in_map", "in_gene", "in_type"})

        rfs = RF_select(
            confirm_file=self.confirm_file,
            in_imp=rf._export["imp"],
            in_rfcv=rf._export["rfcv"],
            errplot=Path("output", "4-Cross-validation-error_plot.pdf"),
            out_gene=Path("output", "4-randomforest_genes.csv"),
            top=config[name]["rf_top"]
        )
        self.append(rfs)
        self._export = {"out_gene": rfs._export["out_gene"]}

class ModelVenn(MyRule):
    def __init__(self, confirm_file, in_files: dict, venn_plot, out_res, color_panel):
        super().__init__()
        if isinstance(color_panel, list):
            color_panel = ",".join(color_panel)
        self._input = in_files
        self._output = {"out_res": out_res}
        self._params = {"in_files": Parameter(in_files, value_type="json"),
                        "venn_plot": self.out_prefix_call(venn_plot)}
        self.script = "model_venn.R"
        self.args = ["{params.in_files}", "{params.venn_plot}", "{output.out_res}", color_panel, "{params.confirm_file}"]
        self.out_res = self.out_prefix_call(out_res)

class TrainSets(RuleSet):
    def __init__(self, config, name, **kwarg):
        super().__init__(config)
        config = self.config
        self.key = "TRAIN"
        models = [str(v).lower() for v in  config[name]["model"]]
        self._params_key = {"in_mat", "in_map", "in_gene"}
        self.ai_file = {
            "a":  Path("assets", "ai", "Z-Machine_learning.ai"),
            "b":  Path("assets", "ai", "Z-Machine_learning-3.ai")
        }

        train_model = {
            "logistic": Logistic(
                confirm_file=self.confirm_file,
                forest=Path("output", "1-Logistic_ForestPlot.pdf"),
                out_gene=Path("output", "1-Logistic_Univarate_result.csv"),
                model_rds_path=Path("output", "1-Logistic_model.rds"),
                top_deg=config[name]["top_deg"],
                seed=config[name]["seed"],
                is_beta=1 if config[name]["is_beta"] else 0,
                ),
            "svm": SVM(
                confirm_file=self.confirm_file,
                out_gene=Path("output", "2-SVM_Genes.csv"),
                error=Path("output", "2-SVM_Error.pdf"),
                accuracy=Path("output", "2-SVM_Accuracy.pdf"),
                imp=Path("output", "2-SVM-imp.pdf"),
                model_rds_path=Path("output", "2-SVM_model.rds"),
                threads=config[name]["nthreads1"],
                seed=config[name]["seed"]
                ),
            "lasso": Lasso(
                confirm_file=self.confirm_file,
                lasso_lambda=Path("output", "3-LASSO_Lambda.pdf"),
                cv=Path("output", "3-LASSO_Likelihood.pdf"),
                out_gene=Path("output", "3-lasso_hubGenes.csv"),
                coef=Path("output", "3-LASSO_Coef.csv"),
                model_rds_path=Path("output", "3-LASSO_model.rds"),
                seed=config[name]["seed"]
                ),
            "randomforest": RF(
                confirm_file=self.confirm_file,
                rfplot=Path("output", "4-randomForest.pdf"),
                imp=Path("output", "4-importance.csv"),
                impplot=Path("output", "4-importance.pdf"),
                rfcv=Path("output", "4-rfcv_mean.csv"),
                seed=config[name]["seed"],
                errplot=Path("output", "4-Cross-validation-error_plot.pdf"),
                out_gene=Path("output", "4-randomforest_genes.csv"),
                top=config[name]["rf_top"],
                model_rds_path=Path("output", "4-randomForest_model.rds")
            ),
            "gbm": Gbm(
                confirm_file=self.confirm_file,
                verify=Path("output", "5-verification.txt"),
                imp=Path("output", "5-GBM_importance.csv"),
                impplot=Path("output", "5-GBM_importance.pdf"),
                out_gene=Path("output", "5-GBM_Genes.csv"),
                top=config[name]["gbm_top"],
                seed=config[name]["seed"],
                model_rds_path=Path("output", "5-GBM_model.rds")
            ),
            "xgboost": Xgb(
                confirm_file=self.confirm_file,
                imp=Path("output", "6-xgb_importance.csv"),
                impplot=Path("output", "6-xgb_importance.pdf"),
                out_gene=Path("output", "6-hub_gene_xgb.csv"),
                threads=config[name]["nthread"],
                seed=config[name]["seed"],
                xgb_top=config[name]["xgb_top"],
                model_rds_path=Path("output", "6-XGBoost_model.rds")
            )
        }
        name_map = {
            "key_gene": "key_gene",
            "logistic": "Logistic",
            "svm": "SVM-RFE",
            "lasso": "Lasso",
            "randomforest": "RandomForest",
            "gbm": "GBM",
            "xgboost": "XGBoost"
        }
        self.train_models = train_model
        self.coef = None
        if config[name]["flow_type"] == "series":
            in_type = "key_gene"
            tmp_gene = kwarg.get("in_gene")
            for model in models:
                rule = train_model[model]
                rule.load_one({"in_gene": tmp_gene}, "in_gene")
                rule.load_one({"in_type": name_map[in_type]}, "in_type")
                tmp_gene = rule._export["out_gene"]
                self.append(rule, {"in_mat", "in_map"})
                in_type = model
                if model == "lasso":
                    self.coef = rule._export["coef"]
            self.out_gene = tmp_gene
        else:
            # 保存原始输入基因用于 SHAP 分析（特别是 XGB）
            self.original_in_gene = kwarg.get("in_gene")
            in_files = {}
            for model in models:
                if model in train_model:
                    rule = train_model[model]
                    rule.load_one({"in_type": "parallel"}, "in_type")
                    self.append(rule, {"in_mat", "in_map", "in_gene"})
                    in_files.update({name_map[model]: Parameter(rule._export["out_gene"], value_type="path", name="gene")})
            venn = ModelVenn(
                confirm_file=self.confirm_file,
                in_files=in_files,
                venn_plot=Path("output", "7-venn_plot.pdf"),
                out_res=Path("output", "hub_genes.csv"),
                color_panel=config["global"]["color_panel"]
            )
            self.append(venn)
            self.out_gene = venn.out_res

        # SHAP分析逻辑：
        # - parallel模式：不做SHAP（由VERIFY对多因素逻辑回归做SHAP）
        # - series模式：只对最后一个机器学习模型做SHAP
        is_series = config[name]["flow_type"] == "series"
        shap_model_map = {
            "lasso": "LASSO",
            "svm": "SVM",
            "randomforest": "RF",
            "gbm": "GBM",
            "xgboost": "XGB"
        }

        self.shap_models = {}
        
        # if is_series:
        #     # series模式：只对最后一个模型做SHAP
        #     last_model = models[-1].lower() if models else None
        #     if last_model in shap_model_map and last_model in train_model:
        #         train_rule = train_model[last_model]
        #         model_path = train_rule._export["model_rds_path"]
        #         model_type = shap_model_map[last_model]
        #         out_gene = train_rule._export["out_gene"]

        #         self.shap_models[last_model] = {
        #             "model_type": model_type,
        #             "model_path": model_path,
        #             "out_gene": out_gene
        #         }

        #         shap_set = ShapSet(
        #             config=config,
        #             in_mat=kwarg.get("in_mat"),
        #             in_map=kwarg.get("in_map"),
        #             model_type=model_type,
        #             model_path=model_path,
        #             gene_path=out_gene
        #         )
        #         self.append(shap_set)
        # parallel模式：不做SHAP（在VERIFY中对多因素逻辑回归做SHAP）