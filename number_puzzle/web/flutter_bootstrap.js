{{flutter_js}}
{{flutter_build_config}}

// Flutter をページ全体ではなく #app（セーフエリアの内側）に描かせる。理由は index.html。
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.querySelector('#app'),
    });
    await appRunner.runApp();
  },
});
