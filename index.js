exports.handler = (event, context, callback) => {
    console.log('hello world');
    callback(null, 'It works');
}