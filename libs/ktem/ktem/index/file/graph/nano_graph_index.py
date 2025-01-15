from typing import Any

from ..base import BaseFileIndexIndexing, BaseFileIndexRetriever
from .graph_index import GraphRAGIndex
from .nano_pipelines import NanoGraphRAGIndexingPipeline, NanoGraphRAGRetrieverPipeline


class NanoGraphRAGIndex(GraphRAGIndex):
    def _setup_indexing_cls(self):
        self._indexing_pipeline_cls = NanoGraphRAGIndexingPipeline

    def _setup_retriever_cls(self):
        self._retriever_pipeline_cls = [NanoGraphRAGRetrieverPipeline]

    def get_indexing_pipeline(self, settings, user_id) -> BaseFileIndexIndexing:
        pipeline = super().get_indexing_pipeline(settings, user_id)
        # indexing settings
        prefix = f"index.options.{self.id}."
        striped_settings = {
            key[len(prefix) :]: value
            for key, value in settings.items()
            if key.startswith(prefix)
        }
        # set the prompts
        pipeline.prompts = striped_settings
        return pipeline

    def get_retriever_pipelines(
        self, settings: dict, user_id: int, selected: Any = None
    ) -> list["BaseFileIndexRetriever"]:
        file_ids = self._selector_ui.get_selected_ids(selected)
        # retrieval settings
        prefix = f"index.options.{self.id}."
        search_type = settings.get(prefix + "search_type", "local")

        retrievers = [
            NanoGraphRAGRetrieverPipeline(
                file_ids=file_ids,
                Index=self._resources["Index"],
                search_type=search_type,
            )
        ]

        return retrievers
