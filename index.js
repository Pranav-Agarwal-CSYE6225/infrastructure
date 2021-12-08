exports.handler = (event, context, callback) => {
    console.log('Testing');
    callback(null, 'Test Lambda function successful');
}